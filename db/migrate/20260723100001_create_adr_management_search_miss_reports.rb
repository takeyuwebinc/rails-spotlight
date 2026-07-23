# frozen_string_literal: true

class CreateAdrManagementSearchMissReports < ActiveRecord::Migration[8.1]
  def change
    create_table :adr_management_search_miss_reports, comment: "ADR検索の取り逃がし報告（検索では見つからなかったが関連 ADR が存在した事例）" do |t|
      t.text :query, null: false, comment: "取り逃がしが起きた検索クエリ"
      t.integer :adr_id, comment: "別経路で到達できた ADR（到達できなかった報告では NULL）"
      t.text :note, null: false, comment: "到達経路・観測メモ"
      t.string :origin, null: false, comment: "記録元（MCP クライアント識別子）"
      t.datetime :created_at, null: false
    end
    add_index :adr_management_search_miss_reports, :created_at,
      name: "idx_adr_search_miss_reports_on_created_at"
  end
end
