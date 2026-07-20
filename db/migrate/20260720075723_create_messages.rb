class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages, comment: "会話内のメッセージ（ruby_llm 標準スキーマ）" do |t|
      t.string :role, null: false, comment: "役割（user/assistant/system/tool）"
      t.text :content, comment: "本文"
      t.json :content_raw, comment: "プロバイダ固有の生コンテンツ"
      t.text :thinking_text, comment: "思考テキスト（対応モデルのみ）"
      t.text :thinking_signature, comment: "思考署名（対応モデルのみ）"
      t.integer :thinking_tokens, comment: "思考トークン数"
      t.integer :input_tokens, comment: "入力トークン数（コスト算出に使用）"
      t.integer :output_tokens, comment: "出力トークン数（コスト算出に使用）"
      t.integer :cached_tokens, comment: "キャッシュ読み取りトークン数"
      t.integer :cache_creation_tokens, comment: "キャッシュ作成トークン数"
      t.timestamps
    end

    add_index :messages, :role
  end
end
