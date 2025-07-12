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

  # Import a single article from markdown content
  # @param markdown_content [String] The markdown content with YAML frontmatter
  # @return [Article, nil] The created/updated article, or nil if failed
  def self.import_from_markdown(markdown_content)
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

    # Parse metadata using MetadataParser service
    parsed_data = MetadataParser.parse(markdown_content)
    metadata = parsed_data[:metadata]
    content = parsed_data[:content]

    # Only process articles
    return nil unless metadata[:category] == "article"

    # Convert markdown to HTML
    html_content = markdown.render(content)

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

      article
    else
      Rails.logger.error "Error saving article: #{article.errors.full_messages.join(', ')}"
      nil
    end
  rescue MetadataParser::MetadataParseError => e
    Rails.logger.error "Metadata parsing error: #{e.message}"
    nil
  rescue => e
    Rails.logger.error "Error processing article: #{e.message}"
    nil
  end

  # Import articles from markdown files
  # @param source_dir [String] Path to the directory containing article markdown files
  # @return [Integer] Number of articles imported
  def self.import_from_docs(source_dir)
    # Find all markdown files in the source directory
    article_files = Dir.glob(File.join(source_dir, "**", "*.md"))

    imported_count = 0
    article_files.each do |file_path|
      puts "Processing article: #{file_path}"

      # Read the file content
      file_content = File.read(file_path)

      # Import the article from markdown content
      article = import_from_markdown(file_content)

      if article
        puts "  Saved article: #{article.title}"
        imported_count += 1
      else
        puts "  Failed to import article from #{file_path}"
      end
    end

    imported_count
  end
end
