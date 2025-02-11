class Rooms::ClosedsController < RoomsController
  before_action :force_room_type, only: %i[ edit update ]

  DEFAULT_ROOM_NAME = "New room"

  def show
    redirect_to room_url(@room)
  end

  def new
    @room  = Rooms::Closed.new(name: DEFAULT_ROOM_NAME)
    @users = User.active.includes(avatar_attachment: :blob).ordered
  end

  def create
    room = Rooms::Closed.create_for(room_params, users: grantees)

    broadcast_create_room(room)
    redirect_to room_url(room)
  end

  def edit
    selected_user_ids = @room.users.pluck(:id)
    @selected_users, @unselected_users = User.active.includes(avatar_attachment: :blob).ordered.partition { |user| selected_user_ids.include?(user.id) }
  end

  def update
    @room.update! room_params
    @room.memberships.revise(granted: grantees, revoked: revokees)

    broadcast_update_room
    redirect_to room_url(@room)
  end

  private
    # Allows us to edit an open room and turn it into a closed one on saving.
    def force_room_type
      @room = @room.becomes!(Rooms::Closed)
    end

    def grantees
      User.where(id: grantee_ids)
    end

    def revokees
      @room.users.where.not(id: grantee_ids)
    end

    def grantee_ids
      params.fetch(:user_ids, [])
    end

    def broadcast_create_room(room)
      for_each_sidebar_section do |list_name|
        each_user_and_html_for_create(room, list_name:) do |user, html|
          broadcast_append_to user, :rooms, target: list_name, html: html, attributes: { maintain_scroll: true }
        end
      end
    end

    def broadcast_update_room
      for_each_sidebar_section do |list_name|
        each_user_and_html_for(@room, list_name:) do |user, html|
          broadcast_replace_to user, :rooms, target: [@room, helpers.dom_prefix(list_name, :list_node)], html: html
        end
      end
    end

    def each_user_and_html_for_create(room, **locals)
      # Optimization to avoid rendering the same partial for every user
      html = render_to_string(partial: "users/sidebars/rooms/shared", locals: { room: room }.merge(locals))

      room.memberships.visible.each do |membership|
        yield membership.user, html
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
