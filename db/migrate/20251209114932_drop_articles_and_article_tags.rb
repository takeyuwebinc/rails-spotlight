class DropArticlesAndArticleTags < ActiveRecord::Migration[8.0]
  def up
    drop_table :article_tags, if_exists: true
    drop_table :articles, if_exists: true
  end

  def down
    create_table :articles do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.text :description
      t.text :content
      t.datetime :published_at

      t.timestamps
    end
    add_index :articles, :slug, unique: true
    add_index :articles, :published_at

    create_table :article_tags do |t|
      t.references :article, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true

      t.timestamps
    end
    add_index :article_tags, [ :article_id, :tag_id ], unique: true
  end
end
