require "rails_helper"

RSpec.describe ContentAgent::ChatCost do
  def create_model_record(model_id)
    Model.create!(model_id: model_id, name: model_id, provider: "openai")
  end

  describe ".for" do
    it "メッセージと下位タスクのトークン量から公表単価で概算する" do
      chat = create(:chat)
      gpt = create_model_record("gpt-oss-120b")
      chat.messages.create!(role: "assistant", content: "a", model: gpt,
                            input_tokens: 10_000, output_tokens: 10_000)
      create(:content_agent_task_usage, chat: chat,
             model_id: "Qwen3-Coder-30B-A3B-Instruct",
             input_tokens: 20_000, output_tokens: 0)

      result = described_class.for(chat)

      # gpt-oss-120b: 0.15 + 0.75 = 0.90 円、抽出: 0.15×2 = 0.30 円
      expect(result.total_yen).to be_within(0.0001).of(1.20)
      expect(result.unknown_model_ids).to be_empty
    end

    it "単価未設定のモデルは合計から除外し、その識別子を報告する" do
      chat = create(:chat)
      unknown = create_model_record("mystery-model")
      chat.messages.create!(role: "assistant", content: "a", model: unknown,
                            input_tokens: 10_000, output_tokens: 0)

      result = described_class.for(chat)

      expect(result.total_yen).to eq(0)
      expect(result.unknown_model_ids).to eq([ "mystery-model" ])
    end

    it "モデル参照のないメッセージは会話進行モデルの単価で概算する" do
      chat = create(:chat)
      chat.messages.create!(role: "assistant", content: "a",
                            input_tokens: 10_000, output_tokens: 0)

      result = described_class.for(chat)

      expect(result.total_yen).to be_within(0.0001).of(0.15)
    end

    it "トークン記録のないメッセージは無視する" do
      chat = create(:chat)
      chat.messages.create!(role: "user", content: "hi")

      result = described_class.for(chat)

      expect(result.total_yen).to eq(0)
    end
  end
end
