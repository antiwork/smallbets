class FeedController < AuthenticatedController
  include RoomParticipants

  before_action :ensure_admin_can_view_feed, only: [:index]
  before_action :require_administrator, only: [:destroy]
  before_action :set_feed_card, only: [:destroy]

  def index
    view = permitted_view(params[:view])

    cards_by_view = feed_cards_by_view
    payload_by_view = build_cards_payload(cards_by_view)
    selected_cards = payload_by_view.fetch(view) { [] }

    respond_to do |format|
      format.html do
        @page_title = "Home"
        @body_class = "sidebar feed-home"

        set_sidebar_memberships

        nav_markup = feed_nav_markup
        sidebar_markup = feed_sidebar_markup

        set_layout_content(nav_markup:, sidebar_markup:)

        render inertia: "feed/index",
          props: {
            cardsByView: payload_by_view,
            initialView: view,
            assets: {
              searchIcon: view_context.asset_path("search.svg"),
            },
            layout: {
              pageTitle: @page_title,
              bodyClass: view_context.body_classes,
              nav: nav_markup,
              sidebar: sidebar_markup,
            },
            flash: {
              notice: flash[:notice],
              alert: flash[:alert],
            },
          },
          view_data: { nav: nav_markup, sidebar: sidebar_markup, body_class: view_context.body_classes }
      end

      format.json do
        render json: { feedCards: selected_cards }
      end
    end
  end

  def destroy
    ActiveRecord::Base.transaction do
      room = @feed_card.room
      @feed_card.destroy
      room.deactivate
    end

    redirect_to root_path, notice: "Feed card and room deleted successfully"
  end

  private

  def permitted_view(view_param)
    view_param == "new" ? "new" : "top"
  end

  def feed_cards_by_view
    top_cards = HomeFeed::Ranker.top(limit: 100)
    new_cards = HomeFeed::Ranker.new(limit: 100)

    {
      "top" => top_cards,
      "new" => new_cards,
    }
  end

  def build_cards_payload(cards_by_view)
    combined_cards = cards_by_view.values.flatten.uniq { |card| card.id }
    return { top: [], new: [] } if combined_cards.empty?

    feed_cards = AutomatedFeedCard
                     .includes(room: [:messages, :memberships, :source_room], preview_message: { creator: { avatar_attachment: :blob } })
                     .where(id: combined_cards.map(&:id))
                     .index_by(&:id)

    loaded_cards = combined_cards.map { |card| feed_cards[card.id] }.compact

    return { top: [], new: [] } if loaded_cards.empty?

    room_ids = loaded_cards.map(&:room_id)

    message_counts = Message.active.where(room_id: room_ids).group(:room_id).count
    reaction_counts = Boost.active
                           .joins(:message)
                           .where(messages: { room_id: room_ids, active: true })
                           .group("messages.room_id")
                           .count

    last_message_times = Message.active
                               .where(room_id: room_ids)
                               .group(:room_id)
                               .maximum(:created_at)

    last_reaction_times = Boost.active
                               .joins(:message)
                               .where(messages: { room_id: room_ids, active: true })
                               .group("messages.room_id")
                               .maximum("boosts.created_at")

    last_activity_by_room = room_ids.index_with do |room_id|
      [last_message_times[room_id], last_reaction_times[room_id]].compact.max
    end

    participants_by_room = participants_for_rooms(room_ids)

    top_reactions_by_room = Boost.active
                                  .joins(:message)
                                  .where(messages: { room_id: room_ids, active: true })
                                  .group("messages.room_id", "boosts.content")
                                  .count
                                  .group_by { |(room_id, _), _| room_id }
                                  .transform_values do |reactions|
                                    reactions
                                      .sort_by { |_, count| -count }
                                      .filter { |(_, content), _| content.to_s.all_emoji? }
                                      .first(5)
                                      .map { |(_, emoji), _| emoji }
                                  end

    payload_by_id = {}

    loaded_cards.each do |card|
      room = card.room
      message_count = message_counts[room.id] || 0
      reaction_count = reaction_counts[room.id] || 0

      participants = Array(participants_by_room[room.id]).map do |user|
        {
          id: user.id,
          name: user.name,
          avatarUrl: view_context.user_image_path(user)
        }
      end

      original_room = room.source_room || room
      room_icon = extract_room_icon(original_room.name)
      original_room_name = view_context.strip_emoji_from_name(original_room.name) || original_room.name || "Conversation"

      top_message = build_top_message_payload(card)

      payload_by_id[card.id] = {
        id: card.id,
        title: card.title,
        summary: card.summary,
        type: card.type,
        createdAt: card.created_at.iso8601,
        topMessage: top_message,
        room: {
          id: room.id,
          slug: room.slug,
          name: room.name,
          originalRoomName: original_room_name,
          icon: room_icon,
          lastActiveAt: last_activity_by_room[room.id]&.iso8601,
          messageCount: message_count,
          reactionCount: reaction_count,
          reactions: top_reactions_by_room[room.id] || [],
          participants: participants
        }
      }
    end

    cards_by_view.transform_values do |cards|
      cards.filter_map { |card| payload_by_id[card.id] }
    end
  end

  def build_top_message_payload(card)
    return nil unless card.preview_message

    body_html, plain_text, opengraph_data = feed_preview_content(card.preview_message)

    {
      id: card.preview_message.id,
      bodyHtml: body_html,
      bodyText: plain_text,
      creatorName: card.preview_message.creator.name,
      creatorAvatarUrl: view_context.user_image_path(card.preview_message.creator),
      opengraph: opengraph_data
    }
  end

  def set_feed_card
    @feed_card = AutomatedFeedCard.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = "Feed card not found"
    redirect_to root_path
  end

  def require_administrator
    head :forbidden unless Current.user&.administrator?
  end

  # TODO: Remove once the feed becomes available to everyone.
  def ensure_admin_can_view_feed
    return if Current.user&.administrator?

    if request.format.html?
      redirect_to talk_path, status: :see_other
    else
      head :forbidden
    end
  end

  def set_layout_content(nav_markup:, sidebar_markup:)
    view_context.content_for(:nav, nav_markup)
    view_context.content_for(:sidebar, sidebar_markup)
  end

  def feed_nav_markup
    view_context.safe_join(
      [
        (view_context.account_logo_tag if Current.account&.logo&.attached?),
        view_context.tag.span(class: "btn btn--reversed btn--faux room--current") do
          view_context.tag.h1("Home", class: "room__contents txt-medium overflow-ellipsis")
        end,
        view_context.tag.div("", id: "feed-search-root", class: "flex w-full"),
      ].compact
    ).to_s
  end

  def feed_sidebar_markup
    view_context.render(template: "users/sidebars/show")
  end

  def feed_preview_content(message)
    return default_preview_content(message) unless message.respond_to?(:body) && message.body&.body

    require "nokogiri"

    fragment = Nokogiri::HTML::DocumentFragment.parse(message.body.body.to_html)
    embed_node = fragment.at_css("action-text-attachment[content-type='#{ActionText::Attachment::OpengraphEmbed::OPENGRAPH_EMBED_CONTENT_TYPE}']")

    return default_preview_content(message) unless embed_node

    embed = ActionText::Attachment::OpengraphEmbed.from_node(embed_node) ||
            ActionText::Attachment::OpengraphEmbed.new(
              href: embed_node["href"],
              url: embed_node["url"],
              filename: embed_node["filename"],
              description: embed_node["caption"],
            )

    embed_html = view_context.render(
      partial: "action_text/attachables/opengraph_embed_feed",
      formats: [:html],
      locals: { opengraph_embed: embed }
    )

    opengraph_data = {
      title: embed.filename,
      imageUrl: embed.url,
      href: embed.href
    }

    [embed_html, nil, opengraph_data]
  end

  def default_preview_content(message)
    html = view_context.message_presentation(message)

    if html.present?
      require "nokogiri"
      fragment = Nokogiri::HTML::DocumentFragment.parse(html)
      fragment.css("turbo-frame").remove
      fragment.css("blockquote, cite").remove

      text_content = fragment.text.strip
      has_media = fragment.css("img, video, action-text-attachment").any?

      if text_content.present? || has_media
        fragment.css("*").each do |node|
          next if node.name == "img" || node.name == "video"
          next if node.css("img, video, action-text-attachment").any?
          node.remove if node.text.strip.empty? && node.children.none?
        end

        cleaned_html = fragment.to_html.strip
        html = cleaned_html.present? && cleaned_html !~ /\A\s*<\s*\/?[^>]+>\s*\z/ ? cleaned_html : nil
      else
        html = nil
      end
    end
    
    plain_text = message.plain_text_body.to_s.strip.presence

    [html, plain_text, nil]
  end

  def extract_room_icon(room_name)
    return nil if room_name.blank?

    emoji_pattern = /\A([\p{Emoji_Presentation}\p{Extended_Pictographic}]|[\p{Emoji}]\uFE0F)/
    
    if match = room_name.match(emoji_pattern)
      match[1]
    else
      room_name.strip[0]&.upcase
    end
  end

end
