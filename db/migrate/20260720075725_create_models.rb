class CreateModels < ActiveRecord::Migration[8.1]
  def change
    create_table :models, comment: "LLMモデル情報（ruby_llm モデルレジストリ）" do |t|
      t.string :model_id, null: false, comment: "モデル識別子（API上のモデル名）"
      t.string :name, null: false, comment: "表示名"
      t.string :provider, null: false, comment: "プロバイダ名"
      t.string :family
      t.datetime :model_created_at
      t.integer :context_window
      t.integer :max_output_tokens
      t.date :knowledge_cutoff

      t.json :modalities, default: {}
      t.json :capabilities, default: []
      t.json :pricing, default: {}
      t.json :metadata, default: {}

      t.timestamps

      t.index [ :provider, :model_id ], unique: true
      t.index :provider
      t.index :family
    end
  end
end
