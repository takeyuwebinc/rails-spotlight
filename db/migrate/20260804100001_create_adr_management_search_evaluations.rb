# frozen_string_literal: true

class CreateAdrManagementSearchEvaluations < ActiveRecord::Migration[8.1]
  def change
    create_table :adr_management_search_evaluations, comment: "ゴールデンクエリ評価の実行履歴（recall の推移を追う）" do |t|
      t.integer :k, null: false, comment: "recall@k の k"
      t.float :recall, null: false, comment: "recall@k の値（0.0〜1.0）"
      t.json :details, comment: "クエリごとの hit/miss の内訳"
      t.string :origin, null: false, comment: "実行経路（system:monthly-report / manual）"
      t.datetime :created_at, null: false
    end
    add_index :adr_management_search_evaluations, :created_at,
      name: "idx_adr_search_evaluations_on_created_at"
  end
end
