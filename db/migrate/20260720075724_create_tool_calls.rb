class CreateToolCalls < ActiveRecord::Migration[8.1]
  def change
    create_table :tool_calls, comment: "エージェントのツール呼び出し記録（更新経緯の記録を兼ねる）" do |t|
      t.string :tool_call_id, null: false, comment: "プロバイダ発行のツール呼び出しID"
      t.string :name, null: false, comment: "ツール名"
      t.text :thought_signature, comment: "思考署名（対応モデルのみ）"

      t.json :arguments, default: {}, comment: "ツール引数"

      t.timestamps
    end

    add_index :tool_calls, :tool_call_id, unique: true
    add_index :tool_calls, :name
  end
end
