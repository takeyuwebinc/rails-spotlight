class Slide < ApplicationRecord
  has_many :slide_pages, -> { order(:position) }, dependent: :destroy
  has_many :slide_tags, dependent: :destroy
  has_many :tags, through: :slide_tags

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :description, presence: true
  validates :published_at, presence: true

  scope :published, -> { where("published_at <= ?", Time.current).order(published_at: :desc) }
  scope :draft, -> { where("published_at > ?", Time.current) }
  scope :tagged_with, ->(tag_slug) { joins(:tags).where(tags: { slug: tag_slug }) }

  def to_param
    slug
  end

  def published?
    published_at <= Time.current
  end

  def draft?
    !published?
  end

  def page_count
    slide_pages.count
  end

  def page_at(position)
    slide_pages.find_by(position: position)
  end

  def public_url
    default_options = Rails.application.config.action_mailer.default_url_options || {}
    host = default_options[:host] || "takeyuweb.co.jp"
    protocol = default_options[:protocol] || "https"
    Rails.application.routes.url_helpers.slide_url(self, host: host, protocol: protocol)
  end

  # Import a single slide from markdown content
  # @param markdown_content [String] The markdown content with YAML frontmatter
  # @return [Slide, nil] The created/updated slide, or nil if failed
  def self.import_from_markdown(markdown_content)
    # MetadataParserを使用してメタデータ解析
    parsed_data = MetadataParser.parse(markdown_content)
    metadata = parsed_data[:metadata]
    content = parsed_data[:content]

    # カテゴリがslideの場合のみ処理
    return nil unless metadata[:category] == "slide"

    # スライドの検索または初期化
    slide = find_or_initialize_by(slug: metadata[:slug])

    # 属性の更新
    slide.assign_attributes(
      title: metadata[:title],
      description: metadata[:description],
      published_at: metadata[:published_date]
    )

    # トランザクション内で保存
    ActiveRecord::Base.transaction do
      if slide.save
        # 既存のページを削除
        slide.slide_pages.destroy_all

        # 新しいページを作成
        create_slide_pages(slide, content)

        # タグの処理
        process_tags(slide, metadata[:tags])

        slide
      else
        Rails.logger.error "Error saving slide: #{slide.errors.full_messages.join(', ')}"
        nil
      end
    end
  rescue MetadataParser::MetadataParseError => e
    Rails.logger.error "Metadata parsing error: #{e.message}"
    nil
  rescue => e
    Rails.logger.error "Error processing slide: #{e.message}"
    nil
  end

  # Import slides from markdown files
  # @param source_dir [String] Path to the directory containing slide markdown files
  # @return [Integer] Number of slides imported
  def self.import_from_docs(source_dir)
    # Find all markdown files in the source directory
    slide_files = Dir.glob(File.join(source_dir, "**", "*.md"))

    imported_count = 0
    slide_files.each do |file_path|
      puts "Processing slide: #{file_path}"

      # Read the file content
      file_content = File.read(file_path)

      # Import the slide from markdown content
      slide = import_from_markdown(file_content)

      if slide
        puts "  Saved slide: #{slide.title}"
        imported_count += 1
      else
        puts "  Failed to import slide from #{file_path}"
      end
    end

    imported_count
  end

  private

  def self.create_slide_pages(slide, markdown_content)
    # スライドを---で分割
    pages = markdown_content.split(/^---$/m).map(&:strip).reject(&:empty?)

    # 各ページをHTMLにレンダリングして保存
    renderer = CustomHtmlRenderer.new(hard_wrap: true)
    markdown = Redcarpet::Markdown.new(renderer, {
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      highlight: true
    })

    pages.each_with_index do |page_content, index|
      # Marpディレクティブの処理
      processed_content = process_marp_directives(page_content)
      html_content = markdown.render(processed_content)

      slide.slide_pages.create!(
        content: html_content,
        position: index + 1
      )
    end
  end

  def self.process_marp_directives(content)
    # Marpディレクティブを削除（HTMLコメントとして残っているもの）
    content.gsub(/<!--\s*\w+:\s*\w+\s*-->/, "")
  end

  def self.process_tags(slide, tag_names)
    return unless tag_names

    slide.tags.clear
    tag_names.each do |tag_name|
      next if tag_name.blank?

      tag = Tag.find_or_create_by(name: tag_name)
      slide.tags << tag unless slide.tags.include?(tag)
    end
  end
end
