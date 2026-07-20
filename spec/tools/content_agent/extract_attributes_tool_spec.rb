require "rails_helper"

RSpec.describe ContentAgent::ExtractAttributesTool do
  describe "#execute" do
    it "抽出用モデルで属性候補を取得し利用量を記録する" do
      stub_request(:post, "https://api.ai.sakura.ad.jp/v1/chat/completions")
        .with(body: hash_including("model" => "Qwen3-Coder-30B-A3B-Instruct"))
        .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: {
          id: "c1", object: "chat.completion",
          choices: [ { index: 0, message: { role: "assistant", content: '{"title":"Fukuoka.rb #100"}' },
                      finish_reason: "stop" } ],
          usage: { prompt_tokens: 120, completion_tokens: 30 }
        }.to_json)
      chat = create(:chat)

      result = described_class.new(chat: chat).execute(
        target_type: "SpeakingEngagement", text: "Fukuoka.rb #100 に登壇しました"
      )

      expect(result[:extracted]).to include("Fukuoka.rb #100")
      usage = chat.task_usages.last
      expect(usage.task_kind).to eq("extraction")
      expect(usage.model_id).to eq("Qwen3-Coder-30B-A3B-Instruct")
      expect(usage.input_tokens).to eq(120)
      expect(usage.output_tokens).to eq(30)
    end

    it "失敗時はエラーを返す" do
      stub_request(:post, "https://api.ai.sakura.ad.jp/v1/chat/completions").to_return(status: 500)
      chat = create(:chat)

      result = described_class.new(chat: chat).execute(target_type: "Project", text: "t")

      expect(result[:error]).to be_present
      expect(chat.task_usages.count).to eq(0)
    end
  end
end
