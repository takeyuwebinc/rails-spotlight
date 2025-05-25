class CreateSpeakingEngagements < ActiveRecord::Migration[8.0]
  def change
    create_table :speaking_engagements do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.string :event_name, null: false
      t.date :event_date, null: false
      t.string :location
      t.text :description
      t.string :event_url
      t.string :slides_url
      t.text :tags
      t.integer :position, default: 999
      t.boolean :published, default: true

      t.timestamps
    end
    add_index :speaking_engagements, :slug, unique: true
    add_index :speaking_engagements, :event_date
    add_index :speaking_engagements, [ :published, :event_date ]
  end
end
