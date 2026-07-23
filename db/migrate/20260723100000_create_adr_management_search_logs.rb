# frozen_string_literal: true

class CreateAdrManagementSearchLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :adr_management_search_logs, comment: "ADR検索の実行ログ（取り逃がし分析・0件率把握用）" do |t|
      t.string :mode, null: false, comment: "検索モード（natural_language / keyword）"
      t.text :query, comment: "自然言語検索のクエリ本文"
      t.text :keyword, comment: "キーワード検索の検索語"
      t.integer :engagement_id, comment: "検索対象の案件（案件横断検索では NULL）"
      t.json :filters, comment: "適用した属性フィルタ"
      t.json :results, comment: "返却結果（adr_id とスコアの配列）"
      t.integer :result_count, null: false, comment: "結果件数（キーワード検索は limit 適用前の総数）"
      t.string :origin, null: false, comment: "記録元（MCP クライアント識別子）"
      t.datetime :created_at, null: false
    end
    add_index :adr_management_search_logs, :created_at,
      name: "idx_adr_search_logs_on_created_at"
  end
end
