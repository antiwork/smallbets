require "zlib"

module Users::AvatarsHelper
  AVATAR_COLORS = %w[
    #AF2E1B #CC6324 #3B4B59 #BFA07A #ED8008 #ED3F1C #BF1B1B #736B1E #D07B53
    #736356 #AD1D1D #BF7C2A #C09C6F #698F9C #7C956B #5D618F #3B3633 #67695E
  ]

  def avatar_background_color(user)
    AVATAR_COLORS[Zlib.crc32(user.to_param) % AVATAR_COLORS.size]
  end

  def avatar_link_tag(user, **options)
    link_to user_path(user), title: user.title, class: "btn avatar", data: { turbo_frame: "_top" } do
      avatar_image_tag(user, size: 48, **options)
    end
  end

  def avatar_tag(user, **options)
    span_attributes = {}

    span_attributes[:title] = options.delete(:title) || user.title
    span_attributes[:class] = ["btn avatar", options.delete(:class)].compact.join(" ")

    span_data = options.delete(:data)
    span_attributes[:data] = span_data if span_data.present?

    existing_style = options.delete(:style)
    image_url = user_image_path(user)

    style_fragments = []
    if image_url.present?
      safe_url = ERB::Util.html_escape(image_url)
      style_fragments << "background-image: url('#{safe_url}')"
      style_fragments << "background-size: cover"
      style_fragments << "background-position: center"
    end
    style_fragments << existing_style if existing_style.present?
    span_attributes[:style] = style_fragments.compact.join("; ") if style_fragments.any?

    image_options = options.dup
    image_size = image_options.delete(:size) || 48

    tag.span(**span_attributes) do
      avatar_image_tag(user, size: image_size, **image_options)
    end
  end

  def avatar_image_tag(user, **options)
    if user.avatar.attached? || user.avatar_url.present? || user.bot?
      options[:loading] ||= :lazy
      image_tag user_image_path(user), aria: { hidden: "true" }, **options
    else
      avatar_monogram_tag(user)
    end
  end

  def avatar_monogram_tag(user)
    initials = user.name.split.map(&:first).first(2).join.upcase
    color_index = Zlib.crc32(user.to_param) % AVATAR_COLORS.size

    tag.div(
      initials,
      class: "avatar-monogram avatar-monogram--#{color_index}",
      "aria-label": user.name,
      title: user.title,
    )
  end

  def user_image_path(user)
    if user.avatar.attached?
      fresh_user_avatar_path(user)
    elsif user.avatar_url.present?
      user.avatar_url
    elsif user.bot?
      asset_path("default-bot-avatar.svg")
    else
      initials = render template: "users/avatars/show", formats: [ :svg ], locals: { user: user }
      "data:image/svg+xml,#{svg_to_uri(initials)}"
    end
  end

  def svg_to_uri(svg)
    # Remove comments, xml meta, and doctype
    svg = svg.gsub(/<!--.*?-->|<\?.*?\?>|<!.*?>/m, "").gsub(/\s+/, " ").gsub("> <", "><").gsub(/([\w:])="(.*?)"/, "\\1='\\2'").strip
    svg = Rack::Utils.escape(svg)
    # Un-escape characters in the given URI-escaped string that do not need escaping in "-quoted data URIs
    svg = svg.gsub("%3D", "=").gsub("%3A", ":").gsub("%2F", "/").gsub("%27", "'").tr("+", " ")
  end
end
