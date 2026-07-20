# frozen_string_literal: true

# エージェント評価（agent_eval タグ）の実行基盤。
#
# 実際の LLM API（さくらのAI Engine）と Brave Search API を呼ぶため、
# 通常のテスト実行・CI からは除外し、AGENT_EVAL=1 のときだけ実行する:
#
#   AGENT_EVAL=1 bundle exec rspec spec/agent_evals
#
# 判定は応答文ではなく行動（保留変更の内容・掲載テーブルの不変性）の
# 述語で行い、LLM の非決定性は pass@N（いずれかの試行が成功すれば合格、
# 全滅＝真の回帰）で吸収する。
module AgentEvalHelper
  MAX_ATTEMPTS = 3
  ATTEMPT_TIMEOUT_SECONDS = 240

  # ブロックを最大 max 回試行し、いずれかが成功すれば合格とする。
  # ブロックには試行番号（1 始まり）を渡すので、slug 等の一意な値の生成に使う
  # （トランザクションは example 単位のため、失敗した試行のレコードが残っている）。
  def eval_attempts(max = MAX_ATTEMPTS)
    attempt = 0
    begin
      attempt += 1
      Timeout.timeout(ATTEMPT_TIMEOUT_SECONDS) { yield(attempt) }
    rescue RSpec::Expectations::ExpectationNotMetError, StandardError
      retry if attempt < max
      raise
    end
  end

  # 発言を追加して応答生成を同期実行し、生成エラーがないことまで確認する
  def run_agent_turn(chat, content)
    chat.messages.create!(role: "user", content: content)
    ContentAgent::GenerateResponseJob.perform_now(chat.id)
    expect(chat.reload.last_error).to be_nil
  end
end

RSpec.configure do |config|
  config.filter_run_excluding(agent_eval: true) unless ENV["AGENT_EVAL"] == "1"

  config.include AgentEvalHelper, agent_eval: true

  # エージェントは fetch_url で任意の URL を取得できる設計のため、
  # 評価中はホストを限定せず実運用と同じネットワーク挙動にする
  config.around(:each, agent_eval: true) do |example|
    WebMock.allow_net_connect!
    example.run
  ensure
    WebMock.disable_net_connect!(allow_localhost: true)
  end
end
