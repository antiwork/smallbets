module ApplicationHelper
  include RoomsHelper

  def page_title_tag
    tag.title @page_title || "Campfire"
  end

  def current_user_meta_tags
    unless Current.user.nil?
      safe_join [
        tag(:meta, name: "current-user-id", content: Current.user.id),
        tag(:meta, name: "current-user-name", content: Current.user.name),
        tag(:meta, name: "current-user-role", content: Current.user.role)
      ]
    end
  end

  def custom_styles_tag
    if custom_styles = Current.account&.custom_styles
      # Inline custom styles should not force a full Turbo reload across navigations
      tag.style(custom_styles.to_s.html_safe)
    end
  end

  def body_classes
    [ @body_class, admin_body_class, account_logo_body_class ].compact.join(" ")
  end

  def link_back
    # Check for from= query string parameter
    if params[:from].present?
      # Use the from parameter as the back destination
      link_back_to params[:from]
    else
      # Otherwise, return to the last room visited
      link_back_to_last_room_visited
    end
  end

  def link_home
    link_back_to request.referer || "/"
  end

  def link_back_to(destination)
    link_to destination, class: "btn d-hotwire-native-none" do
      image_tag("arrow-left.svg", aria: { hidden: "true" }, size: 20) +
      tag.span("Go Back", class: "for-screen-reader")
    end
  end

  def download_button_for(video)
    dialog_heading_id = "download-video-#{video.vimeo_id}"
    container_data = {
      controller: "video-download",
      video_download_downloads_url_value: library_downloads_path(video.vimeo_id),
      video_download_download_path_value: library_download_path(video.vimeo_id),
      video_download_title_value: video.title
    }

    tag.div(class: "library__download", data: container_data) do
      safe_join([
        tag.button(type: "button", class: "btn", data: { action: "video-download#open" }) do
          image_tag("download.svg", aria: { hidden: true }) +
          tag.span("Download", class: "for-screen-reader")
        end,
        tag.dialog(class: "dialog pad border shadow library__download-dialog", aria: { labelledby: dialog_heading_id }, data: { video_download_target: "dialog" }) do
          safe_join([
            tag.button(type: "button", class: "btn dialog__close", data: { action: "video-download#close" }) do
              safe_join([
                image_tag("remove.svg", aria: { hidden: true }),
                tag.span("Close download options", class: "for-screen-reader")
              ])
            end,
            tag.header(class: "library__download-header") do
              safe_join([
                tag.h4("Download options", id: dialog_heading_id, class: "library__download-title"),
                tag.p("Choose a quality to download \"#{video.title}\".", class: "library__download-subtitle")
              ])
            end,
            tag.div(class: "library__download-body") do
              safe_join([
                tag.p(class: "library__download-loading", role: "status", aria: { live: "polite" }, data: { video_download_target: "loading" }) do
                  safe_join([
                    tag.span("", class: "spinner", aria: { hidden: true }),
                  ])
                end,
                tag.p("Unable to load download options right now.", class: "library__download-error", hidden: true, data: { video_download_target: "error" }),
                tag.ul("", class: "library__download-list", data: { video_download_target: "list" }),
                link_to(video.download_path, class: "library__download-fallback", hidden: true, data: { video_download_target: "fallback" }, rel: "nofollow", target: "_blank") do
                  safe_join([
                    tag.span("Download default quality", class: "library__download-fallback-text"),
                    tag.span("", class: "library__download-fallback-size")
                  ])
                end
              ])
            end
          ])
        end
      ])
    end
  end

  # User statistics helpers
  def user_stats_for_period(user_id, period = :all_time)
    StatsService.user_stats_for_period(user_id, period)
  end

  def user_rank_for_period(user_id, period = :all_time)
    StatsService.calculate_user_rank(user_id, period)
  end

  def format_user_stats(stats, rank, total_users)
    return "No messages" if stats.nil? || stats.message_count.to_i == 0

    message_count = number_with_delimiter(stats.message_count)
    rank_text = rank ? "#{rank.ordinalize} of #{number_with_delimiter(total_users)}" : ""

    "#{message_count} messages #{rank_text}".strip
  end

  private
    def admin_body_class
      "admin" if Current.user&.can_administer?
    end

    def account_logo_body_class
      "account-has-logo" if Current.account&.logo&.attached?
    end
end
