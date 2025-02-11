class Rooms::OpensController < RoomsController
  before_action :force_room_type, only: %i[ edit update ]

  DEFAULT_ROOM_NAME = "New room"

  def show
    redirect_to room_url(@room)
  end

  def new
    @room = Rooms::Open.new(name: DEFAULT_ROOM_NAME)
  end

  def create
    @room = Rooms::Open.create_for(room_params, users: Current.user)

    broadcast_create_room
    redirect_to room_url(@room)
  end

  def edit ; end

  def update
    @room.update! room_params

    broadcast_update_room
    redirect_to room_url(@room)
  end

  private
    # Allows us to edit a closed room and turn it into an open one on saving.
    def force_room_type
      @room = @room.becomes!(Rooms::Open)
    end

    def broadcast_create_room
      for_each_sidebar_section do |list_name|
        broadcast_append_to :rooms, target: list_name, partial: "users/sidebars/rooms/shared", locals: { list_name:, room: @room }, attributes: { maintain_scroll: true }
      end
    end

    def broadcast_update_room
      for_each_sidebar_section do |list_name|
        each_user_and_html_for(@room, list_name:) do | user, html |
          broadcast_replace_to user, :rooms, target: [@room, helpers.dom_prefix(list_name, :list_node)], html: html 
        end
      end
    end

  def each_user_and_html_for(room, **locals)
    html_cache = {}

    room.memberships.visible.includes(:user).with_has_unread_notifications.each do |membership|
      yield membership.user, render_or_cached(html_cache,
                                              partial: "users/sidebars/rooms/shared",
                                              locals: { membership: }.merge(locals))
    end
  end
end
