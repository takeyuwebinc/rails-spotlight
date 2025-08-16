class CreateSlides < ActiveRecord::Migration[8.0]
  def change
    create_table :slides do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.text :description, null: false
      t.datetime :published_at, null: false

      t.timestamps
    end

    add_index :slides, :slug, unique: true
    add_index :slides, :published_at
  end
end
