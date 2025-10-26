class Stylesheets
  @cached_paths = {}

  def self.from(sub_folder)
    if Rails.env.production?
      @cached_paths[sub_folder] ||= load_stylesheets_from(sub_folder)
    else
      load_stylesheets_from(sub_folder)
    end
  end

  def self.vendor_stylesheets
    @cached_paths[:vendor] ||= load_vendor_stylesheets
  end

  def self.load_stylesheets_from(sub_folder)
    base = Rails.root.join("app", "assets", "stylesheets")

    Dir.glob(base.join(sub_folder, "**", "*.css")).sort.map do |file|
      Pathname.new(file).relative_path_from(base).to_s.sub(/\.css\z/, "")
    end
  end

  def self.load_vendor_stylesheets
    vendor_assets = []

    Rails.application.config.assets.paths.each do |asset_path|
      asset_path = asset_path.to_s
      next if asset_path == Rails.root.join("app/assets/stylesheets").to_s

      Dir.glob(File.join(asset_path, "**", "*.css")).sort.each do |file|
        vendor_assets << Pathname.new(file).relative_path_from(asset_path).to_s.sub(/\.css\z/, "")
      end
    end

    vendor_assets.uniq
  end
end
