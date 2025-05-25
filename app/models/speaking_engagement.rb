class SpeakingEngagement < ApplicationRecord
  has_many :speaking_engagement_tags, dependent: :destroy
  has_many :tags, through: :speaking_engagement_tags

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :event_name, presence: true
  validates :event_date, presence: true

  scope :published, -> { where(published: true) }
  scope :ordered, -> { order(event_date: :desc, position: :asc) }
  scope :by_year, ->(year) { where(event_date: Date.new(year).beginning_of_year..Date.new(year).end_of_year) }

  def to_param
    slug
  end

  # Import speaking engagements from markdown files
  # @param source_dir [String] Path to the directory containing speaking engagement markdown files
  # @return [Integer] Number of speaking engagements imported
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
    engagement_files = Dir.glob(File.join(source_dir, "**", "*.md"))

    imported_count = 0
    engagement_files.each do |file_path|
      begin
        puts "Processing speaking engagement: #{file_path}"

        # Read the file content
        file_content = File.read(file_path)

        # Parse metadata using MetadataParser service
        parsed_data = MetadataParser.parse(file_content)
        metadata = parsed_data[:metadata]
        markdown_content = parsed_data[:content]

        # Skip if not a speaking engagement
        next unless metadata[:category] == "speaking_engagement"

        # Convert markdown to HTML
        html_content = markdown.render(markdown_content)

        # Find or create speaking engagement by slug
        engagement = find_or_initialize_by(slug: metadata[:slug])

        # Update speaking engagement attributes from parsed metadata
        engagement.title = metadata[:title]
        engagement.event_name = metadata[:event_name]
        engagement.event_date = metadata[:event_date]
        engagement.location = metadata[:location]
        engagement.description = html_content
        engagement.event_url = metadata[:event_url]
        engagement.slides_url = metadata[:slides_url]
        engagement.position = metadata[:position] || 999
        engagement.published = metadata[:published] != false

        # Save the speaking engagement
        if engagement.save
          # Process tags if present
          if metadata[:tags]
            engagement.tags.clear # Remove existing tags

            metadata[:tags].each do |tag_name|
              next if tag_name.blank?

              tag = Tag.find_or_create_by(name: tag_name)
              engagement.tags << tag unless engagement.tags.include?(tag)
            end
          end

          puts "  Saved speaking engagement: #{engagement.title}"
          imported_count += 1
        else
          puts "  Error saving speaking engagement: #{engagement.errors.full_messages.join(', ')}"
        end
      rescue MetadataParser::MetadataParseError => e
        puts "  Metadata parsing error for #{file_path}: #{e.message}"
      rescue => e
        puts "  Error processing speaking engagement #{file_path}: #{e.message}"
      end
    end

    # Mark engagements as unpublished if their markdown files no longer exist
    existing_slugs = engagement_files.map do |file_path|
      begin
        file_content = File.read(file_path)
        parsed_data = MetadataParser.parse(file_content)
        metadata = parsed_data[:metadata]
        metadata[:category] == "speaking_engagement" ? metadata[:slug] : nil
      rescue
        nil
      end
    end.compact

    # Find engagements that exist in database but not in files
    missing_engagements = where.not(slug: existing_slugs)
    missing_engagements.update_all(published: false)

    if missing_engagements.any?
      puts "Marked #{missing_engagements.count} engagements as unpublished (files not found):"
      missing_engagements.each { |engagement| puts "  - #{engagement.title} (#{engagement.slug})" }
    end

    imported_count
  end
end
