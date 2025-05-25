class UsesItem < ApplicationRecord
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :category, presence: true
  validates :description, presence: true

  scope :by_category, ->(category) { where(category: category) }
  scope :published, -> { where(published: true) }
  scope :ordered, -> { order(:position, :created_at) }

  def to_param
    slug
  end

  # Import uses items from markdown files
  # @param source_dir [String] Path to the directory containing uses item markdown files
  # @return [Integer] Number of uses items imported
  def self.import_from_docs(source_dir)
    require "redcarpet"

    # Initialize Markdown renderer with custom renderer for special syntax
    renderer = CustomHtmlRenderer.new(hard_wrap: true)
    markdown = Redcarpet::Markdown.new(renderer, {
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      highlight: true,
      superscript: true,
      underline: true,
      quote: true
    })

    # Find all markdown files in the source directory (including subdirectories)
    item_files = Dir.glob(File.join(source_dir, "**", "*.md"))

    imported_count = 0
    item_files.each do |file_path|
      begin
        puts "Processing uses item: #{file_path}"

        # Read the file content
        file_content = File.read(file_path)

        # Parse metadata using MetadataParser service
        parsed_data = MetadataParser.parse(file_content)
        metadata = parsed_data[:metadata]
        markdown_content = parsed_data[:content]

        # Skip if not a uses item
        next unless metadata[:category] == "uses_item"

        # Convert markdown to HTML
        html_content = markdown.render(markdown_content)

        # Find or create uses item by slug
        uses_item = find_or_initialize_by(slug: metadata[:slug])

        # Update uses item attributes from parsed metadata
        uses_item.name = metadata[:name]
        uses_item.category = metadata[:item_category]
        uses_item.description = html_content
        uses_item.url = metadata[:url]
        uses_item.position = metadata[:position] || 999
        uses_item.published = metadata[:published] != false

        # Save the uses item
        if uses_item.save
          puts "  Saved uses item: #{uses_item.name}"
          imported_count += 1
        else
          puts "  Error saving uses item: #{uses_item.errors.full_messages.join(', ')}"
        end
      rescue MetadataParser::MetadataParseError => e
        puts "  Metadata parsing error for #{file_path}: #{e.message}"
      rescue => e
        puts "  Error processing uses item #{file_path}: #{e.message}"
      end
    end

    # Mark items as unpublished if their markdown files no longer exist
    existing_slugs = item_files.map do |file_path|
      begin
        file_content = File.read(file_path)
        parsed_data = MetadataParser.parse(file_content)
        metadata = parsed_data[:metadata]
        metadata[:category] == "uses_item" ? metadata[:slug] : nil
      rescue
        nil
      end
    end.compact

    # Find items that exist in database but not in files
    missing_items = where.not(slug: existing_slugs)
    missing_items.update_all(published: false)

    if missing_items.any?
      puts "Marked #{missing_items.count} items as unpublished (files not found):"
      missing_items.each { |item| puts "  - #{item.name} (#{item.slug})" }
    end

    imported_count
  end
end
