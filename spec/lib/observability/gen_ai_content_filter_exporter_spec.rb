# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("lib/observability/gen_ai_content_filter_exporter")

RSpec.describe Observability::GenAiContentFilterExporter do
  let(:inner_exporter) { RecordingExporter.new }
  let(:exporter) { described_class.new(inner_exporter, filter_keys: [ :email, :token, :secret ]) }

  # エクスポートされた SpanData を記録するだけのフェイク
  class RecordingExporter
    attr_reader :exported_batches, :force_flush_called, :shutdown_called

    def initialize
      @exported_batches = []
    end

    def export(span_datas, timeout: nil)
      @exported_batches << span_datas
      OpenTelemetry::SDK::Trace::Export::SUCCESS
    end

    def force_flush(timeout: nil)
      @force_flush_called = true
      OpenTelemetry::SDK::Trace::Export::SUCCESS
    end

    def shutdown(timeout: nil)
      @shutdown_called = true
      OpenTelemetry::SDK::Trace::Export::SUCCESS
    end
  end

  def build_span_data(attributes)
    OpenTelemetry::SDK::Trace::SpanData.new.tap { |span_data| span_data.attributes = attributes }
  end

  def exported_attributes
    inner_exporter.exported_batches.last.first.attributes
  end

  describe "#export" do
    it "JSON のツール引数のうち filter_keys に一致するキーの値をマスクする" do
      span_data = build_span_data(
        "gen_ai.tool.call.arguments" => JSON.generate({ "url" => "https://example.com", "token" => "abc123" })
      )

      exporter.export([ span_data ])

      parsed = JSON.parse(exported_attributes["gen_ai.tool.call.arguments"])
      expect(parsed["token"]).to eq("[FILTERED]")
      expect(parsed["url"]).to eq("https://example.com")
    end

    it "メッセージ配列の入れ子構造でも一致するキーの値をマスクする" do
      messages = [ { "role" => "user", "content" => "こんにちは", "metadata" => { "email" => "user@example.com" } } ]
      span_data = build_span_data("gen_ai.input.messages" => JSON.generate(messages))

      exporter.export([ span_data ])

      parsed = JSON.parse(exported_attributes["gen_ai.input.messages"])
      expect(parsed.first.dig("metadata", "email")).to eq("[FILTERED]")
      expect(parsed.first["content"]).to eq("こんにちは")
    end

    it "部分一致するキー（passw に対する password 等）もマスクする" do
      filtering = described_class.new(inner_exporter, filter_keys: [ :passw ])
      span_data = build_span_data("gen_ai.tool.call.arguments" => JSON.generate({ "password" => "hunter2" }))

      filtering.export([ span_data ])

      parsed = JSON.parse(exported_attributes["gen_ai.tool.call.arguments"])
      expect(parsed["password"]).to eq("[FILTERED]")
    end

    it "JSON としてパースできない値はそのまま通す" do
      span_data = build_span_data("gen_ai.tool.call.result" => "素の文字列の結果 token=xyz")

      exporter.export([ span_data ])

      expect(exported_attributes["gen_ai.tool.call.result"]).to eq("素の文字列の結果 token=xyz")
    end

    it "内容属性以外（トークン数など）は変更しない" do
      span_data = build_span_data(
        "gen_ai.usage.input_tokens" => 42,
        "gen_ai.output.messages" => JSON.generate([ { "role" => "assistant", "content" => "ok" } ])
      )

      exporter.export([ span_data ])

      expect(exported_attributes["gen_ai.usage.input_tokens"]).to eq(42)
    end

    it "内容属性を持たないスパンは同一オブジェクトのまま委譲する" do
      span_data = build_span_data("http.method" => "GET")

      exporter.export([ span_data ])

      expect(inner_exporter.exported_batches.last.first).to be(span_data)
    end

    it "属性が nil のスパンもそのまま委譲する" do
      span_data = OpenTelemetry::SDK::Trace::SpanData.new

      exporter.export([ span_data ])

      expect(inner_exporter.exported_batches.last.first).to be(span_data)
    end

    it "filter_keys 省略時は Rails の filter_parameters 設定を使う" do
      default_exporter = described_class.new(inner_exporter)
      span_data = build_span_data("gen_ai.tool.call.arguments" => JSON.generate({ "email" => "user@example.com" }))

      default_exporter.export([ span_data ])

      parsed = JSON.parse(exported_attributes["gen_ai.tool.call.arguments"])
      expect(parsed["email"]).to eq("[FILTERED]")
    end
  end

  describe "#force_flush / #shutdown" do
    it "内側のエクスポータへ委譲する" do
      exporter.force_flush
      exporter.shutdown

      expect(inner_exporter.force_flush_called).to be(true)
      expect(inner_exporter.shutdown_called).to be(true)
    end
  end
end
