class Article < ApplicationRecord
  has_rich_text :content

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :description, presence: true
  validates :published_at, presence: true

  scope :published, -> { where("published_at <= ?", Time.current).order(published_at: :desc) }

  def to_param
    slug
  end

  # Import articles from markdown files
  # @param source_dir [String] Path to the directory containing article markdown files
  # @return [Integer] Number of articles imported
  def self.import_from_docs(source_dir)
    require "redcarpet"

    # Initialize Markdown renderer
    renderer = Redcarpet::Render::HTML.new(hard_wrap: true)
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

        # Extract frontmatter and content using regex
        frontmatter_match = file_content.match(/\A---\s*\n(.*?)\n---\s*\n(.*)\z/m)

        if frontmatter_match
          frontmatter_text = frontmatter_match[1]
          markdown_content = frontmatter_match[2]

          # Extract metadata using regex
          title_match = frontmatter_text.match(/title:\s*(.+)$/)
          slug_match = frontmatter_text.match(/slug:\s*(.+)$/)
          description_match = frontmatter_text.match(/description:\s*(.+)$/)
          published_date_match = frontmatter_text.match(/published_date:\s*(.+)$/)

          # Convert markdown to HTML
          html_content = markdown.render(markdown_content)

          # Find or create article by slug
          slug = slug_match ? slug_match[1].strip : nil

          if slug.nil?
            puts "  Error: No slug found in frontmatter: #{file_path}"
            next
          end

          article = find_or_initialize_by(slug: slug)

          # Update article attributes
          article.title = title_match ? title_match[1].strip : "Untitled"
          article.description = description_match ? description_match[1].strip : ""

          # Set the published date
          if published_date_match
            article.published_at = published_date_match[1].strip
          else
            article.published_at = Time.current
          end

          # Save the article to create it if it's new
          if article.save
            # Update the rich text content
            article.update(content: html_content)
            puts "  Saved article: #{article.title}"
            imported_count += 1
          else
            puts "  Error saving article: #{article.errors.full_messages.join(', ')}"
          end
        else
          puts "  Error: File does not contain valid frontmatter: #{file_path}"
        end
      rescue => e
        puts "  Error processing article #{file_path}: #{e.message}"
      end
    end

    imported_count
  end
end
