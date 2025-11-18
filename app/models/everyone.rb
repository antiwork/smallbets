class Everyone
  include GlobalID::Identification
  include ActionText::Attachable
  extend ActiveModel::Naming

  # Stub object to satisfy avatar.attached? checks
  class NullAvatar
    def attached?
      false
    end
  end

  def self.find(id)
    new
  end

  def id
    "everyone"
  end

  def to_global_id(options = {})
    GlobalID.new("gid://smallbets/Everyone/everyone")
  end

  def name
    "@everyone"
  end

  def initials
    "E"
  end

  def ascii_name
    "everyone"
  end

  def twitter_username
    nil
  end

  def linkedin_username
    nil
  end

  def avatar_url
    nil
  end

  def avatar
    NullAvatar.new
  end

  def bot?
    false
  end

  def to_param
    "everyone"
  end

  def title
    nil
  end

  def to_attachable_partial_path
    "everyone/mention"
  end

  def to_trix_content_attachment_partial_path
    "everyone/mention"
  end

  def attachable_plain_text_representation(caption = nil)
    "@everyone"
  end
end
