module MessagesHelper
  def edit_message_in_room_path(room, message)
    room ? edit_room_message_path(room, message) : edit_message_path(message)
  end

  def message_in_room_path(room, message)
    room ? room_message_path(room, message) : message_path(message)
  end

  def message_area_tag(room, &)
    tag.div id: "message-area", class: "message-area", contents: true, data: {
      controller: "messages presence drop-target",
      action: [ messages_actions, drop_target_actions, presence_actions ].join(" "),
      messages_first_of_day_class: "message--first-of-day",
      messages_first_unread_class: "message__new-separator",
      messages_formatted_class: "message--formatted",
      messages_me_class: "message--me",
      messages_mentioned_class: "message--mentioned",
      messages_threaded_class: "message--threaded",
      messages_loading_up_class: "message--loading-up",
      messages_loading_down_class: "message--loading-down",
      messages_page_url_value: room_messages_url(room)
    }, &
  end

  def messages_tag(room, &)
    tag.div id: dom_id(room, :messages), class: "messages", data: {
      controller: "maintain-scroll refresh-room",
      action: [ maintain_scroll_actions, refresh_room_actions ].join(" "),
      messages_target: "messages",
      refresh_room_loaded_at_value: room.updated_at.to_fs(:epoch),
      refresh_room_url_value: room_refresh_url(room),
      refresh_room_first_unread_class: "message__new-separator"
    }, &
  end

  def message_tag(message, &)
    message_timestamp_milliseconds = message.created_at.to_fs(:epoch)

    tag.div id: dom_id(message),
      class: "message #{"message--emoji" if message.plain_text_body.all_emoji?}",
      data: {
        controller: "reply",
        user_id: message.creator_id,
        message_id: message.id,
        message_timestamp: message_timestamp_milliseconds,
        message_updated_at: message.updated_at.to_fs(:epoch),
        sort_value: message_timestamp_milliseconds,
        messages_target: "message",
        search_results_target: "message",
        refresh_room_target: "message",
        inbox_target: "message",
        reply_composer_outlet: "#composer"
      }, &
  rescue Exception => e
    Sentry.capture_exception(e, extra: { message: message })
    Rails.logger.error "Exception while rendering message #{message.class.name}##{message.id}, failed with: #{e.class} `#{e.message}`"

    render "messages/unrenderable"
  end

  def message_timestamp(message, style: :time, **attributes)
    local_datetime_tag message.created_at, style: style, **attributes
  end

  def message_presentation(message)
    case message.content_type
    when "attachment"
      message_attachment_presentation(message)
    when "sound"
      message_sound_presentation(message)
    else
      auto_link h(ContentFilters::TextMessagePresentationFilters.apply(message.body.body)), html: { target: "_blank" }
    end
  rescue Exception => e
    Sentry.capture_exception(e, extra: { message: message })
    Rails.logger.error "Exception while generating message representation for #{message.class.name}##{message.id}, failed with: #{e.class} `#{e.message}`"

    ""
  end

  def message_cache_key(message, room_id: nil, is_first_unread_message: false, is_parent: false, show_room_name: false)
    [
      message,
      room_id,
      message.bookmarked_by_current_user?,
      message.creator,
      is_first_unread_message,
      is_parent,
      show_room_name
    ]
  end

  private
    def messages_actions
      "turbo:before-stream-render@document->messages#beforeStreamRender keydown.up@document->messages#editMyLastMessage"
    end

    def maintain_scroll_actions
      "turbo:before-stream-render@document->maintain-scroll#beforeStreamRender"
    end

    def refresh_room_actions
      "visibilitychange@document->refresh-room#visibilityChanged online@window->refresh-room#online"
    end

    def presence_actions
      "visibilitychange@document->presence#visibilityChanged"
    end

    def message_attachment_presentation(message)
      Messages::AttachmentPresentation.new(message, context: self).render
    end

    def message_sound_presentation(message)
      sound = message.sound

      tag.div class: "sound", data: { controller: "sound", action: "messages:play->sound#play", sound_url_value: asset_path(sound.asset_path) } do
        play_button + (sound.image ? sound_image_tag(sound.image) : sound.text)
      end
    end

    def play_button
      tag.button "🔊", class: "btn btn--plain", data: { action: "sound#play" }
    end

    def sound_image_tag(image)
      image_tag image.asset_path, width: image.width, height: image.height, class: "align--middle"
    end

    def message_author_title(author)
      [ author.name, author.bio ].compact_blank.join(" – ")
    end
end
