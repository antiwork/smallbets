class LibraryController < AuthenticatedController
  def index
    @page_title = "Library"
    @body_class = "sidebar"

    nav_markup = library_nav_markup
    sidebar_markup = library_sidebar_markup

    set_layout_content(nav_markup:, sidebar_markup:)

    render inertia: "library/index", props: LibraryCatalog
      .inertia_props(user: Current.user)
      .merge(layout: layout_payload(nav_markup:, sidebar_markup:))
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

  def layout_payload(nav_markup:, sidebar_markup:)
    {
      bodyClass: view_context.body_classes,
      nav: nav_markup,
      sidebar: sidebar_markup
    }
  end

  def library_nav_markup
    view_context.safe_join(
      [
        (view_context.account_logo_tag if Current.account&.logo&.attached?),
        view_context.tag.span(class: "btn btn--reversed btn--faux room--current") do
          view_context.tag.h1("Library", class: "room__contents txt-medium overflow-ellipsis")
        end,
        view_context.link_home
      ].compact
    ).to_s
  end

  def library_sidebar_markup
    view_context.sidebar_turbo_frame_tag(src: view_context.user_sidebar_path).to_s
  end
end
