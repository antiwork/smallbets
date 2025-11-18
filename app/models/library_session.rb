class LibrarySession < ApplicationRecord
  belongs_to :library_class
  has_many :library_watch_histories, dependent: :destroy

  after_commit :warm_vimeo_thumbnail, on: %i[create update]

  validates :vimeo_id, presence: true
  validates :padding, presence: true, numericality: { greater_than: 0 }
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :featured_position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  default_scope { order(position: :asc) }

  scope :featured, -> { where(featured: true) }
  scope :featured_ordered, -> { featured.order(featured_position: :asc, position: :asc, id: :asc) }

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

  private

  def warm_vimeo_thumbnail
    return if vimeo_id.blank?
    Vimeo::ThumbnailFetcher.enqueue(vimeo_id)
  end
end
