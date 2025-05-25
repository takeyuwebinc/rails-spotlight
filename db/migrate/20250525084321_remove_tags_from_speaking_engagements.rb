class RemoveTagsFromSpeakingEngagements < ActiveRecord::Migration[8.0]
  def change
    remove_column :speaking_engagements, :tags, :text
  end
end
