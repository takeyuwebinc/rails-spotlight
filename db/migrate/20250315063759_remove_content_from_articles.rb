class RemoveContentFromArticles < ActiveRecord::Migration[8.0]
  def change
    remove_column :articles, :content, :text
  end
end
