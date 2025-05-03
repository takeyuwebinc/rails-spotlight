class MigrateArticleContentFromActionText < ActiveRecord::Migration[8.0]
  def up
    # For each article, copy the content from ActionText to the new content column
    rich_texts = ActiveRecord::Base.connection.execute(
      "SELECT record_id, body FROM action_text_rich_texts WHERE record_type = 'Article' AND name = 'content'"
    )

    rich_texts.each do |row|
      article_id = row['record_id']
      html_content = row['body']

      if html_content.present?
        ActiveRecord::Base.connection.execute(
          "UPDATE articles SET content = #{ActiveRecord::Base.connection.quote(html_content)} WHERE id = #{article_id}"
        )
      end
    end
  end

  def down
    # This migration is not reversible since we're removing ActionText
    raise ActiveRecord::IrreversibleMigration
  end
end
