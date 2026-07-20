# frozen_string_literal: true

module ContentAgent
  # 長いテキスト（取得したページ本文・貼り付けられたメモ等）から
  # 対象種別の属性候補を抽出する下位タスク。会話進行とは別の
  # 抽出用モデルで実行し、利用トークンは TaskUsage に記録して
  # 会話コスト概算に含める。
  class ExtractAttributesTool < RubyLLM::Tool
    # 既定のツール名は名前空間込み（content_agent--extract_attributes）になり、
    # モデルが指示文中の短い名前で呼び出して失敗しやすいため短縮名に固定する
    def name = "extract_attributes"

    description "テキスト素材から掲載内容の属性候補（JSON）を抽出する。" \
                "取得したページ本文や長いメモの整理に使う。結果は候補であり、" \
                "不足・不確かな値は管理者に確認すること。"

    param :target_type, desc: "対象種別: Project / SpeakingEngagement / UsesItem / Slide"
    param :text, desc: "素材テキスト（ページ本文・メモ等）"

    def initialize(chat:)
      super()
      @chat = chat
    end

    def execute(target_type:, text:)
      return { error: "target_type は #{PendingChange::TARGET_TYPES.join(' / ')} のいずれかを指定してください" } unless PendingChange::TARGET_TYPES.include?(target_type)

      model_id = ContentAgent.model_for(:extraction)
      llm = RubyLLM.chat(model: model_id, provider: :openai, assume_model_exists: true)
      response = llm.ask(<<~PROMPT)
        次のテキストから #{target_type} の属性候補を抽出し、JSON オブジェクトだけを出力してください。
        テキストに存在しない値は含めないでください。

        #{text.to_s.truncate(6_000)}
      PROMPT

      record_usage(model_id, response)
      { extracted: response.content }
    rescue StandardError => e
      { error: "属性抽出に失敗しました: #{e.message}" }
    end

    private

    def record_usage(model_id, response)
      @chat.task_usages.create!(
        task_kind: "extraction",
        model_id: model_id,
        input_tokens: response.input_tokens.to_i,
        output_tokens: response.output_tokens.to_i
      )
    end
  end
end
