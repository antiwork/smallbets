# Rooms open to all users on the account. When a new user is added to the account, they're automatically granted membership.
class Rooms::Open < Room
  after_save_commit :grant_access_to_all_users

  private
    def grant_access_to_all_users
      return unless type_previously_changed?(to: "Rooms::Open")

      # Find the IDs of users who are already members of this room
      existing_member_ids = self.memberships.pluck(:user_id)

      # Find all active users who are NOT already members
      users_to_add = User.active.where.not(id: existing_member_ids)

      # Grant memberships ONLY to the new users
      memberships.grant_to(users_to_add) if users_to_add.exists?
    end
end