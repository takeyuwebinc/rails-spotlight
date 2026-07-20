# frozen_string_literal: true

module ContentAgent
  # 会話の LLM 利用コスト概算（円）。保存済みトークン数から、自前で保持する
  # さくらのAI Engine の公表単価で表示時に導出する。コスト自体は保存しない
  # （単価はプロバイダのモデルレジストリから取得できないため自前保持とし、
  # 改定時はこの表だけを更新する。過去分の再計算可否は問わない）。
  class ChatCost
    # 公表単価（税込、円/10,000トークン）。取得日: 2026-07-20
    PRICING_PER_10K_TOKENS = {
      "gpt-oss-120b" => { input: 0.15, output: 0.75 },
      "Qwen3-Coder-480B-A35B-Instruct-FP8" => { input: 0.3, output: 2.5 },
      "Qwen3-Coder-30B-A3B-Instruct" => { input: 0.15, output: 0.75 },
      "llm-jp-3.1-8x13b-instruct4" => { input: 0.15, output: 0.75 }
    }.freeze

    Result = Data.define(:total_yen, :unknown_model_ids)

    def self.for(chat)
      new(chat).result
    end

    def initialize(chat)
      @chat = chat
    end

    def result
      total = 0.0
      unknown = []

      usage_entries.each do |model_id, input_tokens, output_tokens|
        pricing = PRICING_PER_10K_TOKENS[model_id]
        if pricing.nil?
          unknown << model_id
          next
        end
        total += ((input_tokens * pricing[:input]) + (output_tokens * pricing[:output])) / 10_000.0
      end

      Result.new(total_yen: total, unknown_model_ids: unknown.uniq)
    end

    private

    def usage_entries
      message_entries + task_usage_entries
    end

    def message_entries
      @chat.messages.includes(:model).filter_map do |message|
        next if message.input_tokens.to_i.zero? && message.output_tokens.to_i.zero?

        model_id = message.model&.model_id || ContentAgent.model_for(:conversation)
        [ model_id, message.input_tokens.to_i, message.output_tokens.to_i ]
      end
    end

    def task_usage_entries
      @chat.task_usages.map do |usage|
        [ usage.model_id, usage.input_tokens, usage.output_tokens ]
      end
    end
  end
end
