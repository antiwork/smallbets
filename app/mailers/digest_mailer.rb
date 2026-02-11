class DigestMailer < ApplicationMailer
  helper RoomsHelper

  def weekly(user, rooms)
    @user = user
    @rooms = rooms
    @digest_date = Date.current

    mail(to: @user.email_address, subject: "Your weekly digest — #{@digest_date.strftime("%b %-d, %Y")}")
  end
end
