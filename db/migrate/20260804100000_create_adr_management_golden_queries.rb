# frozen_string_literal: true

class CreateAdrManagementGoldenQueries < ActiveRecord::Migration[8.1]
  def change
    create_table :adr_management_golden_queries, comment: "検索品質回帰のゴールデンクエリ（このクエリならこの ADR が上位に出るべき、の期待ペア）" do |t|
      t.integer :adr_id, null: false, comment: "上位に出るべき ADR"
      t.text :query, null: false, comment: "自然言語クエリ"
      t.text :note, comment: "採用の経緯メモ"
      t.string :origin, null: false, comment: "登録元（seed / admin / MCP クライアント識別子）"
      t.datetime :created_at, null: false
    end
    add_index :adr_management_golden_queries, :adr_id,
      name: "idx_adr_golden_queries_on_adr_id"
  end
end
