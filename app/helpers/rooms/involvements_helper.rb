module Rooms::InvolvementsHelper
  def button_to_change_involvement(room, involvement, from_sidebar: false)
    confirm_message = (from_sidebar && involvement == "everything") ? "Are you sure you want to remove this room from your list?" : nil

    button_to room_involvement_path(room, involvement: next_involvement_for(room, involvement: involvement, from_sidebar:), from_sidebar:),
      method: :put,
      role: "checkbox", aria: { checked: true, labelledby: dom_id(room, :involvement_label) }, tabindex: 0,
      class: "btn #{involvement}",
      data: { turbo_confirm: confirm_message } do
        image_tag("notification-bell-#{involvement}.svg", aria: { hidden: "true" }, size: 20) +
        tag.span(HUMANIZE_INVOLVEMENT[involvement], class: "for-screen-reader", id: dom_id(room, :involvement_label))
    end
  end

  private
    HUMANIZE_INVOLVEMENT = {
      "mentions" => "Room in All Rooms",
      "everything" => "Room in My Rooms"
    }

    SHARED_INVOLVEMENT_ORDER = %w[ mentions everything ]
    DIRECT_INVOLVEMENT_ORDER = %w[ everything nothing ]

    def next_involvement_for(room, involvement:, from_sidebar: false)
      if room.direct?
        DIRECT_INVOLVEMENT_ORDER[DIRECT_INVOLVEMENT_ORDER.index(involvement) + 1] || DIRECT_INVOLVEMENT_ORDER.first
      else
        SHARED_INVOLVEMENT_ORDER[(SHARED_INVOLVEMENT_ORDER.index(involvement) || 0) + 1] || SHARED_INVOLVEMENT_ORDER.first
      end
    end
end
