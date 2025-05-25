# frozen_string_literal: true

# Service class for parsing YAML frontmatter from markdown files
# Provides type-safe parsing and validation of metadata
class MetadataParser < ApplicationService
  # Parse YAML frontmatter from markdown content
  # @param file_content [String] The full markdown file content
  # @return [Hash] Parsed metadata and content
  # @raise [MetadataParseError] When frontmatter is invalid or missing
  def self.parse(file_content)
    new(file_content).call
  end

  def initialize(file_content)
    @file_content = file_content
  end

  def call
    extract_frontmatter_and_content
    parse_yaml_metadata
    validate_metadata

    {
      metadata: @metadata,
      content: @content
    }
  end

  private

  attr_reader :file_content

  def extract_frontmatter_and_content
    frontmatter_match = file_content.match(/\A---\s*\n(.*?)\n---\s*\n(.*)\z/m)

    unless frontmatter_match
      raise MetadataParseError, "File does not contain valid YAML frontmatter"
    end

    @frontmatter_text = frontmatter_match[1]
    @content = frontmatter_match[2].strip
  end

  def parse_yaml_metadata
    @metadata = YAML.safe_load(@frontmatter_text, permitted_classes: [ Date, Time ])
  rescue Psych::SyntaxError => e
    raise MetadataParseError, "Invalid YAML syntax: #{e.message}"
  end

  def validate_metadata
    unless @metadata.is_a?(Hash)
      raise MetadataParseError, "Frontmatter must be a YAML hash"
    end

    # Convert string keys to symbols for consistency
    @metadata = @metadata.transform_keys(&:to_sym)

    # Validate required fields based on category
    case @metadata[:category]
    when "article"
      validate_article_metadata
    when "project"
      validate_project_metadata
    when "uses_item"
      validate_uses_item_metadata
    else
      raise MetadataParseError, "Unknown category: #{@metadata[:category]}"
    end
  end

  def validate_article_metadata
    required_fields = [ :title, :slug, :description, :published_date ]
    validate_required_fields(required_fields)

    # Type conversions and validations
    @metadata[:published_date] = parse_date(@metadata[:published_date])
    @metadata[:tags] = parse_tags(@metadata[:tags]) if @metadata[:tags]
  end

  def validate_project_metadata
    required_fields = [ :title, :published_date ]
    validate_required_fields(required_fields)

    # Type conversions and validations
    @metadata[:published_date] = parse_date(@metadata[:published_date])
    @metadata[:position] = @metadata[:position]&.to_i || 999
    @metadata[:technologies] = parse_technologies(@metadata[:technologies]) if @metadata[:technologies]

    # Set defaults for optional fields
    @metadata[:icon] ||= "fa-code"
    @metadata[:color] ||= "blue-600"
  end

  def validate_required_fields(required_fields)
    missing_fields = required_fields.select { |field| @metadata[field].blank? }

    if missing_fields.any?
      raise MetadataParseError, "Missing required fields: #{missing_fields.join(', ')}"
    end
  end

  def parse_date(date_value)
    case date_value
    when Date, Time
      date_value
    when String
      Date.parse(date_value)
    else
      raise MetadataParseError, "Invalid date format: #{date_value}"
    end
  rescue Date::Error => e
    raise MetadataParseError, "Invalid date: #{e.message}"
  end

  def parse_tags(tags_value)
    case tags_value
    when Array
      tags_value.map(&:to_s).map(&:strip)
    when String
      tags_value.split(",").map(&:strip)
    else
      raise MetadataParseError, "Tags must be an array or comma-separated string"
    end
  end

  def validate_uses_item_metadata
    required_fields = [ :name, :slug, :item_category ]
    validate_required_fields(required_fields)

    # Type conversions and validations
    @metadata[:position] = @metadata[:position]&.to_i || 999
    @metadata[:published] = @metadata[:published] != false
  end

  def parse_technologies(tech_value)
    case tech_value
    when Array
      tech_value.map(&:to_s).map(&:strip).join(", ")
    when String
      tech_value.split(",").map(&:strip).join(", ")
    else
      raise MetadataParseError, "Technologies must be an array or comma-separated string"
    end
  end

  # Custom error class for metadata parsing errors
  class MetadataParseError < StandardError; end
end
