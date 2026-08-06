# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("lib/observability/span_drop_exporter")

RSpec.describe Observability::SpanDropExporter do
  let(:inner_exporter) { OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new }
  let(:exporter) do
    described_class.new(inner_exporter, name_prefixes: %w[SolidQueue:: SolidCache:: SolidCable::])
  end

  def build_span_data(name, attributes: nil)
    OpenTelemetry::SDK::Trace::SpanData.new.tap do |span_data|
      span_data.name = name
      span_data.attributes = attributes
    end
  end

  describe "#export" do
    it "プレフィックスに一致するスパンを除外し、それ以外を送信する" do
      result = exporter.export(
        [
          build_span_data("SolidQueue::ReadyExecution.create"),
          build_span_data("SolidCable::Message.create"),
          build_span_data("default process"),
          build_span_data("chat anthropic")
        ]
      )

      expect(result).to eq(OpenTelemetry::SDK::Trace::Export::SUCCESS)
      expect(inner_exporter.finished_spans.map(&:name)).to eq([ "default process", "chat anthropic" ])
    end

    it "全スパンが除外対象の場合は内側のエクスポータを呼ばず成功を返す" do
      result = exporter.export([ build_span_data("SolidQueue::Process.update") ])

      expect(result).to eq(OpenTelemetry::SDK::Trace::Export::SUCCESS)
      expect(inner_exporter.finished_spans).to be_empty
    end

    it "プレフィックスは前方一致のみで、部分一致では除外しない" do
      exporter.export([ build_span_data("Admin::SolidQueueDashboard#show") ])

      expect(inner_exporter.finished_spans.map(&:name)).to eq([ "Admin::SolidQueueDashboard#show" ])
    end

    it "code.namespace 属性がプレフィックスに一致するスパンを除外する" do
      exporter.export(
        [
          build_span_data("ActiveRecord.transaction", attributes: { "code.namespace" => "SolidQueue::ReadyExecution" }),
          build_span_data("ActiveRecord.transaction", attributes: { "code.namespace" => "ApplicationRecord" })
        ]
      )

      expect(inner_exporter.finished_spans.size).to eq(1)
      expect(inner_exporter.finished_spans.first.attributes).to eq({ "code.namespace" => "ApplicationRecord" })
    end
  end
end
