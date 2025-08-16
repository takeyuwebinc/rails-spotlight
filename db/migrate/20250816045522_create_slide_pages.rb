class CreateSlidePages < ActiveRecord::Migration[8.0]
  def change
    create_table :slide_pages do |t|
      t.references :slide, null: false, foreign_key: true
      t.text :content, null: false
      t.integer :position, null: false

      t.timestamps
    end

    add_index :slide_pages, [ :slide_id, :position ], unique: true
  end
end
