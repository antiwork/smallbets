class Users::EmailSubscriptionsController < ApplicationController
  def show ; end

  def update
    case params[:list]
    when "weekly_digest"
      Current.user.toggle_weekly_digest_subscription
    else
      Current.user.toggle_email_subscription
    end

    redirect_to email_subscription_url
  end
end
