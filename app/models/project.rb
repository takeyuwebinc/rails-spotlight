class Project < ApplicationRecord
  validates :title, presence: true
  validates :description, presence: true
  validates :icon, presence: true
  validates :color, presence: true
  validates :technologies, presence: true

  # 表示順に並べるスコープ
  scope :ordered, -> { order(position: :asc) }

  # 技術タグを配列として取得するメソッド
  def technology_list
    technologies.split(",").map(&:strip)
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

        # Extract frontmatter and content using regex
        frontmatter_match = file_content.match(/\A---\s*\n(.*?)\n---\s*\n(.*)\z/m)

        if frontmatter_match
          frontmatter_text = frontmatter_match[1]
          content_text = frontmatter_match[2].strip

          # Extract metadata using regex
          title_match = frontmatter_text.match(/title:\s*(.+)$/)
          icon_match = frontmatter_text.match(/icon:\s*(.+)$/)
          color_match = frontmatter_text.match(/color:\s*(.+)$/)
          position_match = frontmatter_text.match(/position:\s*(\d+)$/)

          # Technologies might be a list, so handle differently
          technologies = []
          in_technologies = false
          frontmatter_text.each_line do |line|
            if line.strip == "technologies:"
              in_technologies = true
              next
            end

            if in_technologies && line.match(/^\s*-\s*(.+)$/)
              technologies << $1.strip
            end
          end

          # Find or create project by title
          title = title_match ? title_match[1].strip : "Untitled Project"
          project = find_or_initialize_by(title: title)

          # For projects, the description is the content after the frontmatter
          project.description = content_text
          project.icon = icon_match ? icon_match[1].strip : "fa-code"
          project.color = color_match ? color_match[1].strip : "blue-600"

          # Set technologies
          if technologies.any?
            project.technologies = technologies.join(", ")
          else
            project.technologies = ""
          end

          # Set position
          if position_match
            project.position = position_match[1].to_i
          else
            project.position = 999
          end

          # Save the project
          if project.save
            puts "  Saved project: #{project.title}"
            imported_count += 1
          else
            puts "  Error saving project: #{project.errors.full_messages.join(', ')}"
          end
        else
          puts "  Error: File does not contain valid frontmatter: #{file_path}"
        end
      rescue => e
        puts "  Error processing project #{file_path}: #{e.message}"
      end
    end

    imported_count
  end
end
