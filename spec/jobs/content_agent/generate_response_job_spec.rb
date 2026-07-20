require "rails_helper"

RSpec.describe ContentAgent::GenerateResponseJob do
  def stub_streaming_completion(content: "了解しました。")
    sse_body = <<~SSE
      data: {"id":"c1","object":"chat.completion.chunk","choices":[{"index":0,"delta":{"role":"assistant","content":"#{content}"},"finish_reason":null}]}

      data: {"id":"c1","object":"chat.completion.chunk","choices":[{"index":0,"delta":{},"finish_reason":"stop"}],"usage":{"prompt_tokens":42,"completion_tokens":7}}

      data: [DONE]

    SSE
    stub_request(:post, "https://api.ai.sakura.ad.jp/v1/chat/completions")
      .to_return(status: 200, body: sse_body,
                 headers: { "Content-Type" => "text/event-stream" })
  end

  describe "#perform" do
    it "エージェント応答を生成して永続化し、タイトルを設定する" do
      stub_streaming_completion
      chat = create(:chat)
      chat.messages.create!(role: "user", content: "昨日の登壇を登録して")

      described_class.perform_now(chat.id)

      assistant = chat.messages.where(role: "assistant").last
      expect(assistant.content).to eq("了解しました。")
      expect(chat.reload.title).to eq("昨日の登壇を登録して")
      expect(chat.last_error).to be_nil
    end

    it "システムプロンプトをデータベースに永続化しない" do
      stub_streaming_completion
      chat = create(:chat)
      chat.messages.create!(role: "user", content: "こんにちは")

      described_class.perform_now(chat.id)

      expect(chat.messages.where(role: "system").count).to eq(0)
    end

    it "LLM 呼び出し失敗時はエラーを会話に記録する" do
      stub_request(:post, "https://api.ai.sakura.ad.jp/v1/chat/completions")
        .to_return(status: 500, body: "oops")
      chat = create(:chat)
      chat.messages.create!(role: "user", content: "hi")

      described_class.perform_now(chat.id)

      expect(chat.reload.last_error).to include("失敗")
    end

    it "コンテキスト長超過は新しい会話への案内にする" do
      stub_request(:post, "https://api.ai.sakura.ad.jp/v1/chat/completions")
        .to_return(status: 400, body: {
          error: { message: "This model's maximum context length is 131072 tokens" }
        }.to_json, headers: { "Content-Type" => "application/json" })
      chat = create(:chat)
      chat.messages.create!(role: "user", content: "hi")

      described_class.perform_now(chat.id)

      expect(chat.reload.last_error).to include("新しい会話")
    end
  end
end
