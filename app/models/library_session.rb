class LibrarySession < ApplicationRecord
  belongs_to :library_class

  validates :vimeo_id, presence: true
  validates :padding, presence: true, numericality: { greater_than: 0 }
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  default_scope { order(position: :asc) }

  delegate :title, to: :library_class

  def aspect_style
    "--library-aspect: #{padding}%;"
  end

  def player_src
    params = []
    params << "h=#{vimeo_hash}" if vimeo_hash.present?
    params << "badge=0"
    params << "autopause=0"
    params << "player_id=0"
    params << "app_id=58479"
    "https://player.vimeo.com/video/#{vimeo_id}?#{params.join("&")}"
  end

  def download_path
    query = quality.present? ? { quality: quality } : {}
    Rails.application.routes.url_helpers.library_download_path(vimeo_id, query)
  end
end
