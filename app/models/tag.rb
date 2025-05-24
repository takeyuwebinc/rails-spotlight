class Tag < ApplicationRecord
  has_many :article_tags, dependent: :destroy
  has_many :articles, through: :article_tags

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true
  validates :color, presence: true

  before_validation :generate_slug

  scope :ordered, -> { order(:name) }

  def to_param
    slug
  end

  def badge_colors
    case color
    when "red"
      { bg_color: "bg-red-100", text_color: "text-red-800" }
    when "blue"
      { bg_color: "bg-blue-100", text_color: "text-blue-800" }
    when "green"
      { bg_color: "bg-green-100", text_color: "text-green-800" }
    when "yellow"
      { bg_color: "bg-yellow-100", text_color: "text-yellow-800" }
    when "purple"
      { bg_color: "bg-purple-100", text_color: "text-purple-800" }
    when "orange"
      { bg_color: "bg-orange-100", text_color: "text-orange-800" }
    when "pink"
      { bg_color: "bg-pink-100", text_color: "text-pink-800" }
    when "indigo"
      { bg_color: "bg-indigo-100", text_color: "text-indigo-800" }
    else
      { bg_color: "bg-gray-100", text_color: "text-gray-800" }
    end
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
end
