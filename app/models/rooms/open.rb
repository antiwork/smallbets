# Rooms open to all users on the account. When a new user is added to the account, they're automatically granted membership.
class Rooms::Open < Room
  after_save_commit :grant_access_to_all_users

  private
    def grant_access_to_all_users
      return unless type_previously_changed?(to: "Rooms::Open")

      # Find active users who are NOT already members of this room
      users_to_add = User.active
                         .joins("LEFT JOIN memberships ON memberships.user_id = users.id AND memberships.room_id = #{id} AND memberships.active = true")
                         .where("memberships.id IS NULL")

      # Grant memberships ONLY to the new users
      memberships.grant_to(users_to_add) if users_to_add.exists?
    end
end