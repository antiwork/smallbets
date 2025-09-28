class RoomSlugConstraint
  def matches?(request)
    slug = request.params[:slug].to_s.strip.downcase
    return false if slug.blank?

    Room.active.exists?(slug: slug)
  end
end
