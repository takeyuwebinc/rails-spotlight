class CreateSlideTags < ActiveRecord::Migration[8.0]
  def change
    create_table :slide_tags do |t|
      t.references :slide, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true

      t.timestamps
    end

    add_index :slide_tags, [ :slide_id, :tag_id ], unique: true
  end
end
