class SpeakingEngagementTag < ApplicationRecord
  belongs_to :speaking_engagement
  belongs_to :tag

  validates :speaking_engagement_id, uniqueness: { scope: :tag_id }
end
