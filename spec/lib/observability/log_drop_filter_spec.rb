# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("lib/observability/log_drop_filter")

RSpec.describe Observability::LogDropFilter do
  let(:filter) { described_class.new(/\bSolid(?:Queue|Cache|Cable)\b|\bRails::HealthController\b/) }

  def build_log(body)
    Sentry::LogEvent.new(level: :info, body: body)
  end

  describe "#call" do
    it "ジョブ実行ログを破棄する" do
      log = build_log("Performed SolidCable::TrimJob (Job ID: e057ae0e) from SolidQueue(default) in 0.32ms")

      expect(filter.call(log)).to be_nil
    end

    it "structured_logging の DB クエリログを破棄する" do
      log = build_log("Database query: SolidQueue::Process Update")

      expect(filter.call(log)).to be_nil
    end

    it "ヘルスチェックのコントローラログを破棄する" do
      log = build_log("Rails::HealthController#show")

      expect(filter.call(log)).to be_nil
    end

    it "パターンに一致しないログはそのまま返す" do
      log = build_log("Database query: Adr Load")

      expect(filter.call(log)).to be(log)
    end

    it "本文が nil のログはそのまま返す" do
      # LogEvent は body なしで構築できないため、防御的分岐はスタブで検証する
      log = instance_double(Sentry::LogEvent, body: nil)

      expect(filter.call(log)).to be(log)
    end
  end
end
