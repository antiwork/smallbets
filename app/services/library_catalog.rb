require "yaml"

class LibraryCatalog
  Section = Data.define(:slug, :title, :videos)
  Video = Data.define(:title, :vimeo_id, :hash, :padding, :quality, :slug) do
    def aspect_style
      "--library-aspect: #{padding}%;"
    end

    def player_src
      params = []
      params << "h=#{hash}" if hash.present?
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

    def metadata
      # Use a cache key based on the video ID instead of instance variable
      Vimeo::Library.fetch_video_metadata(vimeo_id)
    end

    def duration
      duration_seconds = metadata[:duration]
      return "0:00" unless duration_seconds
      Vimeo::Library.format_duration(duration_seconds)
    end

    def view_count
      views = metadata[:views]
      return "0 views" unless views
      Vimeo::Library.format_view_count(views)
    end

    def views_number
      metadata[:views] || 0
    end

    def created_date
      return nil unless metadata[:created_time]
      Date.parse(metadata[:created_time])
    rescue Date::Error
      nil
    end

    def thumbnail_url
      metadata[:thumbnail_url]
    end

    def embed_url
      params = []
      params << "h=#{hash}" if hash.present?
      params << "autoplay=1"
      params << "badge=0"
      params << "autopause=0"
      params << "player_id=0"
      params << "app_id=58479"
      "https://player.vimeo.com/video/#{vimeo_id}?#{params.join("&")}"
    end

    def author_name
      # Extract author from title (format: "Author Name - Topic - Date")
      parts = title.split(' - ')
      return parts.first if parts.length >= 2
      # Fallback: look for common patterns
      if title.match?(/^([^-]+)\s*-/)
        title.split('-').first.strip
      else
        "Unknown"
      end
    end

    def clean_title
      # Remove author name and date from title
      parts = title.split(' - ')
      return title if parts.length < 2
      
      # Remove author (first part) and try to remove date (last part if it looks like a date)
      remaining = parts[1..-1]
      if remaining.last&.match?(/\b(January|February|March|April|May|June|July|August|September|October|November|December|\d{4})\b/i)
        remaining = remaining[0..-2] if remaining.length > 1
      end
      
      remaining.join(' - ').presence || title
    end

    def topic_category
      # Extract the main topic/category from the title
      clean_title.split(' - ').first || clean_title
    end
  end

  class << self
    def sections
      yaml.fetch("sections", []).map do |section|
        Section.new(
          slug: section.fetch("slug"),
          title: section.fetch("title"),
          videos: section.fetch("videos", []).map { |video| build_video(video, section.fetch("slug")) }
        )
      end
    end

    def total_stats
      Rails.cache.fetch("library_total_stats", expires_in: 1.hour) do
        all_videos = sections.flat_map(&:videos)
        
        total_duration_seconds = all_videos.map { |video| video.metadata[:duration] || 0 }.sum
        total_views = all_videos.map { |video| video.metadata[:views] || 0 }.sum
        total_count = all_videos.size

        {
          total_duration: Vimeo::Library.format_duration(total_duration_seconds),
          total_views: Vimeo::Library.format_view_count(total_views),
          total_count: total_count
        }
      end
    end

    private

    def build_video(data, slug)
      Video.new(
        title: data.fetch("title"),
        vimeo_id: data.fetch("vimeo_id"),
        hash: data["hash"],
        padding: data.fetch("padding", 56.25).to_f,
        quality: data["quality"].presence,
        slug: slug
      )
    end

    def yaml
      @yaml ||= YAML.load_file(Rails.root.join("config", "library_videos.yml"))
    end
  end
end
