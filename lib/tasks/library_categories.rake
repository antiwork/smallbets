namespace :library do
  desc "Populate library categories (idempotent)"
  task populate_categories: :environment do
    categories = [
      { name: "Content creation", slug: "content-creation" },
      { name: "Audience building", slug: "audience-building" },
      { name: "Marketing", slug: "marketing" },
      { name: "Social media", slug: "social-media" },
      { name: "Info products", slug: "info-products" },
      { name: "Business", slug: "business" },
      { name: "Freelancing", slug: "freelancing" },
      { name: "Tech", slug: "tech" },
      { name: "SEO", slug: "seo" },
      { name: "Strategy", slug: "strategy" },
      { name: "Real estate", slug: "real-estate" },
      { name: "Philosophy", slug: "philosophy" },
      { name: "Lifestyle", slug: "lifestyle" }
    ]

    # Map class slugs to category indices (1-based)
    class_categories = {
      "a-practical-guide-to-self-employment-taxes" => [6],
      "a-pragmatic-guide-to-business-ethics" => [10, 12],
      "a-quick-start-guide-to-adult-adhd" => [13],
      "a-stoic-guide-to-dealing-with-uncertainty" => [10, 12],
      "ai-for-the-rest-of-us" => [8],
      "amazon-kdp-crash-course" => [1, 5],
      "art-of-interviewing" => [2],
      "build-in-public-on-twitch" => [1, 2],
      "building-a-content-roadmap-for-seo" => [3, 9],
      "building-businesses-on-wordpress" => [6, 8],
      "building-launching-macos-apps-with-swiftui" => [8],
      "building-media-business" => [1, 2],
      "casual-youtube-creation" => [2, 4],
      "creating-income-through-real-estate" => [6, 11],
      "crowdfunding-crash-course" => [6],
      "delve-into-expiring-domain-names" => [6],
      "domain-first-development" => [6],
      "effortless-screencasting" => [1],
      "emerging-from-the-void-on-x" => [1, 2, 4],
      "enough-gpt-to-be-dangerous" => [8],
      "equity-crowdfunding-for-solopreneurs" => [6],
      "explaining-ideas-visually" => [1],
      "extremely-minimum-viable-video" => [1],
      "fundamentals-of-internet-marketing" => [3],
      "getting-featured-in-the-media" => [1, 2, 3],
      "getting-started-on-youtube" => [1, 2, 4],
      "getting-started-with-midjourney" => [1, 8],
      "getting-started-with-short-term-rentals" => [6, 11],
      "getting-the-attention-of-influential-people" => [2],
      "growing-on-substack" => [1, 2],
      "gumroad-crash-course" => [6, 5],
      "intro-to-google-ads" => [3],
      "intro-to-internet-pipes" => [3],
      "intro-to-seo" => [9],
      "make-500-on-upwork-by-monday" => [6],
      "marketing-fundamentals-for-non-marketers" => [3],
      "notion-for-creators-and-entrepreneurs" => [1, 13],
      "publish-a-best-selling-course-on-udemy" => [1, 5],
      "product-management-in-the-age-of-ai" => [8],
      "reproducible-success-strategies-and-ergodicity" => [10, 12],
      "self-sponsor-your-own-us-green-card" => [13],
      "seo-keyword-research" => [3, 9],
      "small-bets-fundamentals" => [12, 10],
      "spreading-ideas-with-memes" => [1, 2, 4],
      "state-of-the-creator-economy" => [5, 6],
      "the-art-of-podcasting" => [2],
      "the-basics-of-buying-and-selling-businesses" => [6],
      "understanding-linkedin" => [1, 2, 4],
      "understanding-the-x-algorithm" => [1, 2, 4],
      "vibe-code-with-devin-cursor-codex-and-more" => [8],
      "wandering-the-pathless-path" => [10, 13],
      "what-to-expect-when-you-go-self-employed" => [6]
    }

    puts "Populating library categories..."

    # Create/update categories
    category_objects = []
    categories.each do |category_data|
      category = LibraryCategory.find_or_initialize_by(slug: category_data[:slug])
      category.name = category_data[:name]

      if category.new_record?
        category.save!
        puts "  ✓ Created: #{category.name}"
      elsif category.changed?
        category.save!
        puts "  ✓ Updated: #{category.name}"
      else
        puts "  - Exists: #{category.name}"
      end

      category_objects << category
    end

    puts "\n✓ Categories populated: #{LibraryCategory.count} total"

    # Assign classes to categories
    puts "\nAssigning classes to categories..."
    assigned_count = 0
    skipped_count = 0

    class_categories.each do |class_slug, category_indices|
      library_class = LibraryClass.find_by(slug: class_slug)

      unless library_class
        puts "  ⚠ Class not found: #{class_slug}"
        next
      end

      # Get the category objects for this class
      class_category_objects = category_indices.map { |idx| category_objects[idx - 1] }

      # Compare existing associations with desired ones
      existing_ids = library_class.library_categories.order(:id).pluck(:id).sort
      desired_ids = class_category_objects.map(&:id).sort

      # Clear existing associations and set new ones if they differ
      if existing_ids != desired_ids
        library_class.library_categories = class_category_objects
        assigned_count += 1
        puts "  ✓ Assigned: #{library_class.title} → #{class_category_objects.map(&:name).join(', ')}"
      else
        skipped_count += 1
      end
    end

    puts "\n✓ Assigned #{assigned_count} classes, #{skipped_count} already correct"
  end
end
