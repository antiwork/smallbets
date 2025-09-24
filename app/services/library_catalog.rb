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
