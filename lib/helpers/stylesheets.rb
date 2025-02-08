class Stylesheets
  @cached_paths = {}

  def self.from(sub_folder)
    if Rails.env.production?
      @cached_paths[sub_folder] ||= load_stylesheets(sub_folder)
    else
      load_stylesheets(sub_folder)
    end
  end

  def self.load_stylesheets(sub_folder)
    Dir.glob(Rails.root.join("app", "assets", "stylesheets", sub_folder, "*.css")).sort.map do |file|
      "#{sub_folder}/#{File.basename(file, '.css')}"
    end
  end
end