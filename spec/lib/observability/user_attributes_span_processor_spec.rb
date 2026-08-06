# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("lib/observability/user_attributes_span_processor")

RSpec.describe Observability::UserAttributesSpanProcessor do
  let(:exporter) { OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new }

  let(:tracer_provider) do
    OpenTelemetry::SDK::Trace::TracerProvider.new.tap do |provider|
      provider.add_span_processor(described_class.new)
      provider.add_span_processor(OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(exporter))
    end
  end

  after do
    tracer_provider.shutdown
    Current.reset
  end

  describe "#on_start" do
    it "Current.observability_user が設定されていれば user.* 属性を付与する" do
      Current.observability_user = { id: "admin@example.com", email: "admin@example.com", name: "管理者" }

      tracer_provider.tracer("test").in_span("some span") { }

      expect(exporter.finished_spans.first.attributes).to include(
        "user.id" => "admin@example.com",
        "user.email" => "admin@example.com",
        "user.name" => "管理者"
      )
    end

    it "id のみの場合は user.id だけを付与する" do
      Current.observability_user = { id: "oauth:claude" }

      tracer_provider.tracer("test").in_span("some span") { }

      attributes = exporter.finished_spans.first.attributes
      expect(attributes).to include("user.id" => "oauth:claude")
      expect(attributes).not_to include("user.email", "user.name")
    end

    it "未設定の場合は何も付与しない" do
      tracer_provider.tracer("test").in_span("some span") { }

      expect(exporter.finished_spans.first.attributes.keys).not_to include("user.id")
    end
  end

  describe ".apply" do
    it "開始済みのスパンへ遡って付与できる" do
      tracer_provider.tracer("test").in_span("request span") do |span|
        described_class.apply(span, { id: "oauth:claude" })
      end

      expect(exporter.finished_spans.first.attributes).to include("user.id" => "oauth:claude")
    end

    it "user が nil の場合は何もしない" do
      span = instance_double(OpenTelemetry::Trace::Span)

      expect { described_class.apply(span, nil) }.not_to raise_error
    end
  end
end
