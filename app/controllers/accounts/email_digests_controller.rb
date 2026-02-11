class Accounts::EmailDigestsController < ApplicationController
  before_action :ensure_can_administer

  def update
    account = Current.account
    account.update!(email_digest_enabled: !account.email_digest_enabled?)

    redirect_to edit_account_url
  end
end
