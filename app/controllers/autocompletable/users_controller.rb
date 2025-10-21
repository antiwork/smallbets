class Autocompletable::UsersController < ApplicationController
  def index
    @users = find_autocompletable_users
    @users = add_everyone_mention_if_applicable(@users)
  end

  private
    def find_autocompletable_users
      exact_name_matches = users_scope.by_first_name(params[:query])
      all_matches = users_scope.filtered_by(params[:query]).limit(20)

      (all_matches + exact_name_matches).uniq
    end

    def users_scope
      scope = params[:room_id].present? ? Current.user.rooms.find(params[:room_id]).users : User.all
      scope.active.without_default_names.recent_posters_first(params[:room_id]).with_attached_avatar
    end

    def add_everyone_mention_if_applicable(users)
      # Only show @everyone for admins in open rooms
      return users unless Current.user&.administrator?
      return users if params[:room_id].blank?

      room = Current.user.rooms.find(params[:room_id])
      return users unless room.is_a?(Rooms::Open)

      # Add @everyone to the bottom of the list
      users + [ Everyone.new ]
    end
end
