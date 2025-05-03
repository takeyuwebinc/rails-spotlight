class AddContentToArticles < ActiveRecord::Migration[8.0]
  def change
    add_column :articles, :content, :text
  end
end
