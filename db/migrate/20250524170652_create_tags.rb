class CreateTags < ActiveRecord::Migration[8.0]
  def change
    create_table :tags do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :color, default: 'gray'

      t.timestamps
    end

    add_index :tags, :name, unique: true
    add_index :tags, :slug, unique: true
  end
end
