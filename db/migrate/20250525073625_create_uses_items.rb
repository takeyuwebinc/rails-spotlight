class CreateUsesItems < ActiveRecord::Migration[8.0]
  def change
    create_table :uses_items do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :category, null: false
      t.text :description, null: false
      t.string :url
      t.integer :position, default: 999
      t.boolean :published, default: true

      t.timestamps
    end
    add_index :uses_items, :slug, unique: true
    add_index :uses_items, :category
    add_index :uses_items, [ :category, :position ]
  end
end
