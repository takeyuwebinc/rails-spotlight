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
end
