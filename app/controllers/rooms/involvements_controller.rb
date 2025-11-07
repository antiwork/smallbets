class Rooms::InvolvementsController < ApplicationController
  include RoomScoped

  helper_method :from_sidebar

  before_action :set_involvement, only: %i[show notifications_ready]

  def show ; end

  def update
    @membership.update! involvement: params[:involvement]

    broadcast_involvement_changes
    redirect_to room_involvement_url(@room, from_sidebar:)
  end

  def notifications_ready ; end

  private

    def broadcast_involvement_changes
      broadcast_involvement_change_to_room_nav
      broadcast_involvement_change_to_sidebar
      add_or_remove_rooms_in_sidebar
    end

    def from_sidebar
      ActiveModel::Type::Boolean.new.cast(params[:from_sidebar])
    end

    def set_involvement
      @involvement = @membership.involvement
    end

    def broadcast_involvement_change_to_room_nav
      broadcast_replace_to @membership, target: [ @room, :involvement ],
                           partial: "rooms/involvements/involvement",
                           locals: { room: @room, involvement: @membership.involvement, from_sidebar: false }
    end

    def broadcast_involvement_change_to_sidebar
      for_each_sidebar_section do |list_name|
        broadcast_replace_to @membership.user, :rooms,
                             target: [ @room, helpers.dom_prefix(list_name, :list_node) ],
                             partial: "users/sidebars/rooms/shared",
                             locals: { list_name:, membership: @membership }
      end
    end

    def add_or_remove_rooms_in_sidebar
      # No longer needed - rooms are always visible in sidebar (either in "My Rooms" or "All Rooms")
      # The involvement state (mentions vs everything) is handled by broadcast_involvement_change_to_sidebar
    end
end
