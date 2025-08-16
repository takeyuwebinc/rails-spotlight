class Tag < ApplicationRecord
  has_many :article_tags, dependent: :destroy
  has_many :articles, through: :article_tags
  has_many :speaking_engagement_tags, dependent: :destroy
  has_many :speaking_engagements, through: :speaking_engagement_tags
  has_many :slide_tags, dependent: :destroy
  has_many :slides, through: :slide_tags

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true
  validates :bg_color, presence: true
  validates :text_color, presence: true

  before_validation :generate_slug
  before_validation :set_random_colors, on: :create

  scope :ordered, -> { order(:name) }

  def to_param
    slug
  end

  def badge_colors
    { bg_color: "bg-#{bg_color}", text_color: "text-#{text_color}" }
  end

  def description
    "Articles and insights about #{name}. Explore technical content, tutorials, and best practices related to #{name}."
  end

  def page_title
    "#{name} Articles"
  end

  def english_title
    "Exploring #{name}"
  end

  private

  def generate_slug
    self.slug ||= name.parameterize if name.present?
  end

  def set_random_colors
    return if bg_color.present? || text_color.present?

    colors = generate_random_color_pair
    self.bg_color = colors[:bg_color]
    self.text_color = colors[:text_color]
  end

  def generate_random_color_pair
    # Available color families
    color_families = %w[red orange amber yellow lime green emerald teal cyan sky blue indigo violet purple fuchsia pink rose]

    # Select random color family
    color_family = color_families.sample

    # Define intensity ranges for good contrast
    dark_bg_intensities = %w[600 700 800 900]
    light_bg_intensities = %w[100 200 300 400]

    # Randomly choose between dark or light background
    if [ true, false ].sample
      # Dark background with light text
      bg_intensity = dark_bg_intensities.sample
      text_intensity = %w[50 100 200].sample
    else
      # Light background with dark text
      bg_intensity = light_bg_intensities.sample
      text_intensity = %w[700 800 900].sample
    end

    {
      bg_color: "#{color_family}-#{bg_intensity}",
      text_color: "#{color_family}-#{text_intensity}"
    }
  end
end
