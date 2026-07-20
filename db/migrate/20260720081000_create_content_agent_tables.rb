class CreateContentAgentTables < ActiveRecord::Migration[8.1]
  def change
    create_table :content_agent_pending_changes,
                 comment: "エージェントが提案した掲載内容への保留変更（承認されるまで掲載内容と隔離する）" do |t|
      t.references :chat, null: false, foreign_key: true, comment: "提案元の会話"
      t.references :message, foreign_key: true,
                   comment: "提案契機のメッセージ（履歴の時系列配置用。特定できない場合は作成日時で代替）"
      t.string :target_type, null: false, comment: "対象種別（Project/SpeakingEngagement/UsesItem/Slide）"
      t.integer :target_id, comment: "対象レコードID（新規作成時はNULL）"
      t.string :operation, null: false,
               comment: "操作種別（create:新規作成, update:更新, toggle_publication:公開・非公開切替）"
      t.json :payload, null: false, default: {},
             comment: "適用する変更内容（属性の組とタグ名一覧。SlideはMarkdown全文）"
      t.string :status, null: false, default: "pending",
               comment: "状態（pending:承認待ち, approved:承認済み, rejected:否認済み, superseded:置換済み, failed:適用失敗）"
      t.datetime :applied_at, comment: "適用日時（承認済みへの遷移時に記録）"
      t.text :apply_error, comment: "適用失敗時のエラー内容"
      t.timestamps
    end

    add_index :content_agent_pending_changes, [ :chat_id, :status ]

    create_table :content_agent_task_usages,
                 comment: "下位タスク（属性抽出・検索結果要約）のLLM利用量記録（会話コスト算出用）" do |t|
      t.references :chat, null: false, foreign_key: true, comment: "対象の会話"
      t.string :task_kind, null: false, comment: "タスク種別（extraction:属性抽出, summarization:検索結果要約）"
      t.string :model_id, null: false, comment: "使用モデル識別子（単価表の参照キー）"
      t.integer :input_tokens, null: false, default: 0, comment: "入力トークン数"
      t.integer :output_tokens, null: false, default: 0, comment: "出力トークン数"
      t.timestamps
    end
  end
end
