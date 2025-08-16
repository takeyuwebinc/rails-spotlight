class SlideTag < ApplicationRecord
  belongs_to :slide
  belongs_to :tag

  validates :slide_id, uniqueness: { scope: :tag_id }
end
