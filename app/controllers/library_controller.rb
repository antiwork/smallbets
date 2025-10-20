class LibraryController < AuthenticatedController
  def index
    @page_title = "Library"
    @body_class = "library-collapsed"

    # Ensure sidebar memberships are available for initial render
    set_sidebar_memberships

    nav_markup = library_nav_markup
    sidebar_markup = library_sidebar_markup

    set_layout_content(nav_markup:, sidebar_markup:)

    props = LibraryCatalog.inertia_props(user: Current.user)

    # Compute server-rendered thumbnails for above-the-fold cards to remove first paint placeholders
    initial_thumbnails = begin
      continue_watching = props[:continueWatching] || []
      first_shelf = (props[:sections] || []).first || {}
      first_shelf_sessions = first_shelf[:sessions] || []

      priority_ids = (
        continue_watching.map { |s| s[:vimeoId] } +
        first_shelf_sessions.map { |s| s[:vimeoId] }
      ).compact.uniq

      Vimeo::ThumbnailFetcher.read_cached_many(priority_ids)
    rescue => e
      Rails.logger.warn("library.index.initial_thumbnails.error" => { error: e.class.name, message: e.message })
      {}
    end

    render inertia: "library/index",
      props: props.merge(
        assets: {
          downloadIcon: view_context.asset_path("download.svg"),
          backIcon: view_context.asset_path("arrow-left.svg"),
        },
        initialThumbnails: initial_thumbnails,
        initialSessionId: params[:id]&.to_i,
        layout: {
          pageTitle: @page_title,
          bodyClass: view_context.body_classes,
          nav: nav_markup,
          sidebar: sidebar_markup,
        },
      ),
      view_data: { nav: nav_markup, sidebar: sidebar_markup, body_class: view_context.body_classes }
  end

  def show
    @page_title = "Library"
    @body_class = "bg-black"

    # Keep layout empty for watch page
    nav_markup = ""
    sidebar_markup = ""

    set_layout_content(nav_markup:, sidebar_markup:)

    session = LibrarySession.includes(:library_watch_histories, library_class: :library_categories).find_by(id: params[:id])
    return redirect_to library_path unless session

    history = Current.user ? session.library_watch_histories.where(user: Current.user).order(updated_at: :desc).first : nil

    payload = LibraryCatalog.send(:build_session_payload, session, categories: session.library_class.library_categories.map { |c| LibraryCatalog.send(:build_category_payload, c) }, history: history)

    render inertia: "library/watch",
      props: {
        session: payload,
        assets: {
          downloadIcon: view_context.asset_path("download.svg"),
          backIcon: view_context.asset_path("arrow-left.svg"),
        },
        layout: {
          pageTitle: @page_title,
          bodyClass: view_context.body_classes,
          nav: nav_markup,
          sidebar: sidebar_markup,
        },
      },
      view_data: { nav: nav_markup, sidebar: sidebar_markup, body_class: view_context.body_classes }
  end

  def download
    url = Vimeo::Library.fetch_download_url(params[:id], params[:quality])

    if url
      redirect_to url, allow_other_host: true
    else
      head :not_found
    end
  end

  def downloads
    downloads = Vimeo::Library.fetch_downloads(params[:id])

    if downloads.blank?
      head :not_found
    else
      render json: downloads
    end
  end

  private

  def set_layout_content(nav_markup:, sidebar_markup:)
    view_context.content_for(:nav, nav_markup)
    view_context.content_for(:sidebar, sidebar_markup)
  end

  def library_nav_markup
    view_context.safe_join(
      [
        (view_context.account_logo_tag if Current.account&.logo&.attached?),
        view_context.tag.span(class: "btn btn--reversed btn--faux room--current") do
          view_context.tag.h1("Library", class: "room__contents txt-medium overflow-ellipsis")
        end,
        view_context.link_back
      ].compact
    ).to_s
  end

  def library_sidebar_markup
    # Render the full sidebar content immediately on first load so the aside
    # is not empty; still wrapped in a <turbo-frame> for dynamic updates.
    view_context.render(template: "users/sidebars/show")
  end
end
