class AuthToken < ApplicationRecord
  belongs_to :user

  has_secure_token :token

  validates_presence_of :code
  validates_presence_of :expires_at

  before_validation :generate_code

  scope :valid, -> { where(used_at: nil).where("expires_at > ?", Time.current) }

  def deliver_later
    AuthTokenMailer.otp(self).deliver_later
  end

  def use!
    update!(used_at: Time.current)
    user.auth_tokens.without(self).update_all(expires_at: Time.current)
  end

  def self.lookup(token: nil, email_address: nil, code: nil)
    if token.present?
      return valid.find_by(token: token)
    elsif email_address.present? && code.present?
      user = User.find_by(email_address: email_address)

      return valid.find_by(user: user, code: code)
    end

    nil
  end

  private

  def generate_code
    self.code = format("%06d", rand(100_000..999_999))
  end
end
