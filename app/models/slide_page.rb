class SlidePage < ApplicationRecord
  belongs_to :slide

  validates :content, presence: true
  validates :position, presence: true, uniqueness: { scope: :slide_id }

  scope :ordered, -> { order(:position) }

  def next_page
    slide.slide_pages.find_by(position: position + 1)
  end

  def previous_page
    slide.slide_pages.find_by(position: position - 1)
  end

  def first?
    position == 1
  end

  def last?
    position == slide.page_count
  end
end
