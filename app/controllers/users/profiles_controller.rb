class Users::ProfilesController < ApplicationController
  before_action :set_user

  def show
    @shared_memberships = Current.user.memberships.shared.with_ordered_room
  end

  def update
    @user.update user_params
    redirect_to after_update_url, notice: update_notice
  end

  private
    def set_user
      @user = Current.user
    end

    def user_params
      params.require(:user).permit(:name, :avatar, :email_address, :password, :bio, :twitter_url, :linkedin_url, :personal_url).compact
    end

    def after_update_url
      name_changed_from_default? ? root_url : user_profile_url
    end

    def name_changed_from_default?
      @user.name_previously_was == User::DEFAULT_NAME && @user.saved_change_to_name?
    end

    def update_notice
      params[:user][:avatar] ? "It may take up to 30 minutes to change everywhere." : "✓"
    end
end
