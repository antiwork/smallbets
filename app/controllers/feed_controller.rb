class FeedController < AuthenticatedController
  include RoomParticipants
  layout "inertia_app"

  INITIAL_CARDS_LIMIT = 20
  LOAD_MORE_LIMIT = 30

  before_action :require_administrator, only: [:destroy]
  before_action :set_feed_card, only: [:destroy]

  def index
    view = permitted_view(params[:view])
    page = (params[:page] || 1).to_i
    per_page = page == 1 ? INITIAL_CARDS_LIMIT : LOAD_MORE_LIMIT

    respond_to do |format|
      format.html do
        cards_by_view = feed_cards_by_view(limit: INITIAL_CARDS_LIMIT)
        payload_by_view = build_cards_payload(cards_by_view)

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
            pagination: {
              initialLimit: INITIAL_CARDS_LIMIT,
              loadMoreLimit: LOAD_MORE_LIMIT,
            },
            viewer: {
              isAdministrator: Current.user&.administrator? || false,
            },
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
        offset = (page - 1) * per_page
        cards_by_view = feed_cards_by_view(limit: per_page, offset: offset)
        payload_by_view = build_cards_payload(cards_by_view)
        selected_cards = payload_by_view.fetch(view) { [] }

        render json: {
          feedCards: selected_cards,
          hasMore: selected_cards.length >= per_page,
          page: page
        }
      end
    end
  end

  def destroy
    ActiveRecord::Base.transaction do
      room = @feed_card.room
      @feed_card.destroy
      room.deactivate
    end

    respond_to do |format|
      format.json { head :no_content }
      format.html { redirect_to root_path, notice: "Feed card and room deleted successfully" }
    end
  end

  private

  def permitted_view(view_param)
    view_param == "new" ? "new" : "top"
  end

  def feed_cards_by_view(limit: 100, offset: 0)
    @ranker_result = HomeFeed::Ranker.all(limit: limit, offset: offset)

    {
      "top" => @ranker_result.top,
      "new" => @ranker_result.new,
    }
  end

  def build_cards_payload(cards_by_view)
    combined_cards = cards_by_view.values.flatten.uniq { |card| card.id }
    return { top: [], new: [] } if combined_cards.empty?

    feed_cards = AutomatedFeedCard
                     .includes(
                       room: :source_room,
                       preview_message: [:rich_text_body, { creator: { avatar_attachment: :blob } }]
                     )
                     .where(id: combined_cards.map(&:id))
                     .index_by(&:id)

    loaded_cards = combined_cards.map { |card| feed_cards[card.id] }.compact

    return { top: [], new: [] } if loaded_cards.empty?

    room_ids = loaded_cards.map(&:room_id)
    ranker_metrics = @ranker_result.metrics
    boost_data = load_boost_data(room_ids)

    last_message_times = Message.active
                               .where(room_id: room_ids)
                               .group(:room_id)
                               .maximum(:created_at)

    last_activity_by_room = room_ids.index_with do |room_id|
      [last_message_times[room_id], boost_data[:last_reaction_times][room_id]].compact.max
    end

    participants_by_room = participants_for_rooms(room_ids)

    payload_by_id = {}

    loaded_cards.each do |card|
      room = card.room
      room_metrics = ranker_metrics[room.id] || { messages: 0, reactions: 0 }
      message_count = room_metrics[:messages]
      reaction_count = room_metrics[:reactions]

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
          reactions: boost_data[:top_reactions][room.id] || [],
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
    respond_to do |format|
      format.json { head :not_found }
      format.html do
        flash[:alert] = "Feed card not found"
        redirect_to root_path
      end
    end
  end

  def require_administrator
    head :forbidden unless Current.user&.administrator?
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

  def load_boost_data(room_ids)
    message_scope = Message.active.where(room_id: room_ids)

    copied_pairs = message_scope
                     .where.not(original_message_id: nil)
                     .pluck(:room_id, :original_message_id)

    original_to_rooms = copied_pairs.each_with_object(Hash.new { |h, k| h[k] = [] }) do |(room_id, original_id), hash|
      hash[original_id] << room_id
    end

    direct_pairs = message_scope
                     .where(original_message_id: nil)
                     .pluck(:id, :room_id)

    direct_to_room = direct_pairs.to_h { |message_id, room_id| [message_id, room_id] }

    message_ids = (original_to_rooms.keys + direct_to_room.keys).uniq
    return { last_reaction_times: {}, top_reactions: {} } if message_ids.empty?

    raw_data = Boost.active
                    .joins(:message)
                    .where(message_id: message_ids, messages: { active: true })
                    .group("boosts.message_id", "boosts.content")
                    .pluck(
                      Arel.sql("boosts.message_id"),
                      Arel.sql("boosts.content"),
                      Arel.sql("COUNT(*)"),
                      Arel.sql("MAX(boosts.created_at)")
                    )

    last_reaction_times = {}
    reactions_by_room = Hash.new { |h, k| h[k] = Hash.new(0) }

    raw_data.each do |message_id, content, count, max_time|
      next unless content.to_s.all_emoji?

      timestamp = max_time.is_a?(String) ? Time.zone.parse(max_time) : max_time
      target_room_ids = original_to_rooms[message_id].presence || [direct_to_room[message_id]].compact
      next if target_room_ids.empty?

      target_room_ids.each do |room_id|
        current_max = last_reaction_times[room_id]
        if current_max.nil? || timestamp > current_max
          last_reaction_times[room_id] = timestamp
        end
        reactions_by_room[room_id][content] += count
      end
    end

    top_reactions = reactions_by_room.transform_values do |emoji_counts|
      emoji_counts
        .sort_by { |_, emoji_count| -emoji_count }
        .first(5)
        .map(&:first)
    end

    {
      last_reaction_times: last_reaction_times,
      top_reactions: top_reactions
    }
  end

end
