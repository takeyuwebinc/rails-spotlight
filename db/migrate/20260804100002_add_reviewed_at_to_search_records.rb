# frozen_string_literal: true

class AddReviewedAtToSearchRecords < ActiveRecord::Migration[8.1]
  def change
    add_column :adr_management_search_logs, :reviewed_at, :datetime,
      comment: "管理画面レビューの処理日時（0件検索の取り逃がし判定。未処理は NULL）"
    add_column :adr_management_search_miss_reports, :reviewed_at, :datetime,
      comment: "管理画面レビューの処理日時（ゴールデンクエリ採用等。未処理は NULL）"
  end
end
