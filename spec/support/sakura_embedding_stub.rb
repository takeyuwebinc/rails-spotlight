# frozen_string_literal: true

# さくらのAI Engine 埋め込み API のデフォルトスタブ。
# テスト・CI では外部 API を呼ばない前提のため、全テストで決定的な
# ダミーベクトルを返す。挙動を検証するテストは stub_request を上書きする。
RSpec.configure do |config|
  config.before(:each) do
    stub_request(:post, Sakura::EmbeddingClient::ENDPOINT.to_s).to_return do |request|
      inputs = JSON.parse(request.body)["input"]
      inputs = [ inputs ] if inputs.is_a?(String)
      data = inputs.each_with_index.map do |_, index|
        vector = Array.new(8, 0.0)
        vector[index % 8] = 1.0
        { embedding: vector, index: index }
      end
      {
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: { data: data }.to_json
      }
    end
  end
end
