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

    RoomUpdateBroadcastJob.perform_later(@room)
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
end
