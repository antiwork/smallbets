module Users::SidebarHelper
  def has_unreads?
    return unless Current.user.present?

    Current.user.memberships.unread.any?
  end

  def sidebar_turbo_frame_tag(src: nil, &)
    if block_given?
      turbo_frame_tag :user_sidebar, src: src, target: "_top", data: {
        controller: "rooms-list read-rooms turbo-frame",
        rooms_list_unread_class: "unread",
        rooms_list_badge_class: "badge",
        action: "presence:present@window->rooms-list#read read-rooms:read->rooms-list#read turbo:frame-load->rooms-list#loaded refresh-room:visible@window->turbo-frame#reload".html_safe # otherwise -> is escaped
      } do
        yield
      end
    else
      turbo_frame_tag :user_sidebar, src: src, target: "_top", data: {
        controller: "rooms-list read-rooms turbo-frame sidebar-loading",
        rooms_list_unread_class: "unread",
        rooms_list_badge_class: "badge",
        action: "presence:present@window->rooms-list#read read-rooms:read->rooms-list#read turbo:frame-load->rooms-list#loaded turbo:frame-load->sidebar-loading#hide refresh-room:visible@window->turbo-frame#reload".html_safe # otherwise -> is escaped
      } do
        content_tag :div, class: "sidebar__loading", data: { sidebar_loading_target: "indicator" } do
          content_tag :div, "", class: "spinner"
        end
      end
    end
  end
end
