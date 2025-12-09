class Project < ApplicationRecord
  validates :title, presence: true
  validates :description, presence: true
  validates :icon, presence: true
  validates :color, presence: true
  validates :technologies, presence: true
  validates :published_at, presence: true

  # 表示順に並べるスコープ
  scope :ordered, -> { order(position: :asc) }
  scope :published, -> { where("published_at <= ?", Time.current).order(position: :asc) }

  # 技術タグを配列として取得するメソッド
  def technology_list
    technologies.split(",").map(&:strip)
  end

  # Import a single project from markdown content
  # @param markdown_content [String] The markdown content with YAML frontmatter
  # @return [Project, nil] The created/updated project, or nil if failed
  def self.import_from_markdown(markdown_content)
    parsed_data = MetadataParser.parse(markdown_content)
    metadata = parsed_data[:metadata]
    content_text = parsed_data[:content]

    # カテゴリがprojectの場合のみ処理
    return nil unless metadata[:category] == "project"

    # プロジェクトの検索または初期化
    project = find_or_initialize_by(title: metadata[:title])

    # 属性の更新
    project.assign_attributes(
      description: content_text,
      icon: metadata[:icon],
      color: metadata[:color],
      technologies: metadata[:technologies] || "Unknown",
      position: metadata[:position],
      published_at: metadata[:published_date]
    )

    project.save ? project : nil
  rescue MetadataParser::MetadataParseError => e
    Rails.logger.error "Metadata parsing error: #{e.message}"
    nil
  rescue => e
    Rails.logger.error "Error processing project: #{e.message}"
    nil
  end

  # Import projects from markdown files
  # @param source_dir [String] Path to the directory containing project markdown files
  # @return [Integer] Number of projects imported
  def self.import_from_docs(source_dir)
    # Find all markdown files in the source directory
    project_files = Dir.glob(File.join(source_dir, "**", "*.md"))

    imported_count = 0
    project_files.each do |file_path|
      begin
        puts "Processing project: #{file_path}"

        # Read the file content
        file_content = File.read(file_path)

        # Parse metadata using MetadataParser service
        parsed_data = MetadataParser.parse(file_content)
        metadata = parsed_data[:metadata]
        content_text = parsed_data[:content]

        # Skip if not a project
        next unless metadata[:category] == "project"

        # Find or create project by title
        project = find_or_initialize_by(title: metadata[:title])

        # Update project attributes from parsed metadata
        project.description = content_text
        project.icon = metadata[:icon]
        project.color = metadata[:color]
        project.technologies = metadata[:technologies] || "Unknown"
        project.position = metadata[:position]
        project.published_at = metadata[:published_date]

        # Save the project
        if project.save
          puts "  Saved project: #{project.title}"
          imported_count += 1
        else
          puts "  Error saving project: #{project.errors.full_messages.join(', ')}"
        end
      rescue MetadataParser::MetadataParseError => e
        puts "  Metadata parsing error for #{file_path}: #{e.message}"
      rescue => e
        puts "  Error processing project #{file_path}: #{e.message}"
      end
    end

    imported_count
  end
end
