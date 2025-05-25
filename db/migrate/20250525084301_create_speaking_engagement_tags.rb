class CreateSpeakingEngagementTags < ActiveRecord::Migration[8.0]
  def change
    create_table :speaking_engagement_tags do |t|
      t.references :speaking_engagement, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true

      t.timestamps
    end

    add_index :speaking_engagement_tags, [ :speaking_engagement_id, :tag_id ], unique: true
  end
end
