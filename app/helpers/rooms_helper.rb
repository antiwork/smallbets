module RoomsHelper
  def link_to_room(room, **attributes, &)
    path = room.slug.present? ? room_slug_path(room.slug) : room_path(room)
    link_to path, **attributes, data: {
      rooms_list_target: "room", room_id: room.id, badge_dot_target: "unread"
    }.merge(attributes.delete(:data) || {}), &
  end

  def link_to_edit_room(room)
    member_count = room.memberships.visible.joins(:user).where(users: { suspended_at: nil, active: true }).count

    link_to \
      room_stats_path(room),
      class: "btn",
      style: "view-transition-name: edit-room-#{room.id}",
      data: { room_id: room.id } do
        image_tag("person.svg", aria: { hidden: "true" }) +
        tag.span(number_with_delimiter(member_count), class: "hide-on-mobile") +
        tag.span(round_for_mobile(member_count), class: "hide-on-desktop")
    end
  end

  def link_back_to_last_room_visited
    if controller.respond_to?(:last_room_visited)
      # Use the controller's method if available
      if last_room = controller.last_room_visited
        link_back_to room_path(last_room)
      else
        link_back_to root_path
      end
    else
      # Fallback implementation if controller method is not available
      last_room_id = cookies[:last_room]
      if last_room_id.present? && (last_room = Room.find_by(id: last_room_id))
        link_back_to room_path(last_room)
      else
        link_back_to root_path
      end
    end
  end

  def button_to_delete_room(room, url: nil)
    button_to room, method: :delete, class: "btn btn--negative max-width", aria: { label: "Delete #{room.name}" },
        data: { turbo_confirm: "Are you sure you want to delete this room and all messages in it? This can't be undone." } do
      image_tag("trash.svg", aria: { hidden: "true" }, size: 20) +
      tag.span(room_display_name(room), class: "overflow-ellipsis")
    end
  end

  def button_to_jump_to_newest_message
    tag.button \
        class: "message-area__return-to-latest btn",
        data: { action: "messages#returnToLatest", messages_target: "latest" },
        hidden: true do
      image_tag("arrow-down.svg", aria: { hidden: "true" }, size: 20) +
      tag.span("Jump to newest message", class: "for-screen-reader")
    end
  end

  def submit_room_button_tag
    button_tag class: "btn btn--reversed txt-large center", type: "submit" do
      image_tag("check.svg", aria: { hidden: "true" }, size: 20) +
      tag.span("Save", class: "for-screen-reader")
    end
  end

  def composer_form_tag(room, &)
    form_with model: Message.new, url: room_messages_path(room),
      id: "composer", class: "margin-block flex-item-grow contain", data: composer_data_options(room), &
  end

  def room_display_name(room, for_user: Current.user)
    room.display_name(for_user: for_user)
  end

  private
    def composer_data_options(room)
      {
        controller: "composer drop-target",
        action: composer_data_actions,
        composer_messages_outlet: "#message-area",
        composer_toolbar_class: "composer--rich-text", composer_room_id_value: room.id
      }
    end

    def composer_data_actions
      drag_and_drop_actions = "drop-target:drop@window->composer#dropFiles"

      trix_attachment_actions =
        "trix-file-accept->composer#preventAttachment refresh-room:online@window->composer#online"

      remaining_actions =
        "typing-notifications#stop paste->composer#pasteFiles turbo:submit-end->composer#submitEnd refresh-room:offline@window->composer#offline"

      [ drop_target_actions, drag_and_drop_actions, trix_attachment_actions, remaining_actions ].join(" ")
    end

    # round_for_mobile(123)             # => "123"
    # round_for_mobile(1234)            # => "1.2k"
    # round_for_mobile(12345)           # => "12k"
    # round_for_mobile(12345678)        # => "12M"
    def round_for_mobile(number)
      number_to_human(number,
                      precision: number < 10_000 ? 1 : 0,
                      significant: false,
                      format: "%n%u",
                      units: { thousand: "k", million: "M", billion: "B" })
    end
end
