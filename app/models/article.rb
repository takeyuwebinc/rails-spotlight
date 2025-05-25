class Article < ApplicationRecord
  has_many :article_tags, dependent: :destroy
  has_many :tags, through: :article_tags

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :description, presence: true
  validates :content, presence: true
  validates :published_at, presence: true

  scope :published, -> { where("published_at <= ?", Time.current).order(published_at: :desc) }
  scope :tagged_with, ->(tag_slug) { joins(:tags).where(tags: { slug: tag_slug }) }

  def to_param
    slug
  end

  # Import articles from markdown files
  # @param source_dir [String] Path to the directory containing article markdown files
  # @return [Integer] Number of articles imported
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

    # Find all markdown files in the source directory
    article_files = Dir.glob(File.join(source_dir, "**", "*.md"))

    imported_count = 0
    article_files.each do |file_path|
      begin
        puts "Processing article: #{file_path}"

        # Read the file content
        file_content = File.read(file_path)

        # Parse metadata using MetadataParser service
        parsed_data = MetadataParser.parse(file_content)
        metadata = parsed_data[:metadata]
        markdown_content = parsed_data[:content]

        # Skip if not an article
        next unless metadata[:category] == "article"

        # Convert markdown to HTML
        html_content = markdown.render(markdown_content)

        # Find or create article by slug
        article = find_or_initialize_by(slug: metadata[:slug])

        # Update article attributes from parsed metadata
        article.title = metadata[:title]
        article.description = metadata[:description]
        article.published_at = metadata[:published_date]
        article.content = html_content

        # Save the article
        if article.save
          # Process tags if present
          if metadata[:tags]
            article.tags.clear # Remove existing tags

            metadata[:tags].each do |tag_name|
              next if tag_name.blank?

              tag = Tag.find_or_create_by(name: tag_name)
              article.tags << tag unless article.tags.include?(tag)
            end
          end

          puts "  Saved article: #{article.title}"
          imported_count += 1
        else
          puts "  Error saving article: #{article.errors.full_messages.join(', ')}"
        end
      rescue MetadataParser::MetadataParseError => e
        puts "  Metadata parsing error for #{file_path}: #{e.message}"
      rescue => e
        puts "  Error processing article #{file_path}: #{e.message}"
      end
    end

    imported_count
  end
end
