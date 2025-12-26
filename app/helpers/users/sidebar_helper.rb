module Users::SidebarHelper
  def has_unreads?
    return unless Current.user.present?

    Current.user.memberships.unread.any?
  end

  def sidebar_turbo_frame_tag(src: nil, &)
    content = if block_given?
      yield
    else
      content_tag :div, class: "sidebar__loading", data: { sidebar_loading_target: "indicator" } do
        content_tag :div, "", class: "spinner"
      end
    end

    turbo_frame_tag :user_sidebar, src: src, target: "_top", data: {
      controller: "rooms-list read-rooms turbo-frame sidebar-loading",
      rooms_list_unread_class: "unread",
      rooms_list_badge_class: "badge",
      action: "presence:present@window->rooms-list#read read-rooms:read->rooms-list#read turbo:frame-load->rooms-list#loaded turbo:frame-load->sidebar-loading#hide turbo:before-frame-render->sidebar-loading#show refresh-room:visible@window->turbo-frame#reload".html_safe # otherwise -> is escaped
    } do
      content
    end
  end
end
