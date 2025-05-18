class CreateLinkMetadata < ActiveRecord::Migration[8.0]
  def change
    create_table :link_metadata do |t|
      t.string :url, null: false
      t.string :title, null: false, default: ""
      t.text :description, null: false, default: ""
      t.string :domain, null: false, default: ""
      t.string :favicon, null: false, default: ""
      t.string :image_url, null: false, default: ""
      t.datetime :last_fetched_at, null: false

      t.timestamps null: false
    end
    add_index :link_metadata, :url, unique: true
  end
end
