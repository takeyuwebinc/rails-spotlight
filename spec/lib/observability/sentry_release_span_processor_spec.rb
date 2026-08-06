# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("lib/observability/sentry_release_span_processor")

RSpec.describe Observability::SentryReleaseSpanProcessor do
  let(:exporter) { OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new }

  let(:tracer_provider) do
    OpenTelemetry::SDK::Trace::TracerProvider.new.tap do |provider|
      provider.add_span_processor(described_class.new("abc123"))
      provider.add_span_processor(OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(exporter))
    end
  end

  after { tracer_provider.shutdown }

  it "エクスポートされるスパンに sentry.release を付与する" do
    tracer_provider.tracer("test").in_span("some span") { }

    expect(exporter.finished_spans.first.attributes).to include("sentry.release" => "abc123")
  end

  it "子スパンにも付与する" do
    tracer_provider.tracer("test").in_span("parent") do
      tracer_provider.tracer("test").in_span("child") { }
    end

    expect(exporter.finished_spans.map { |span| span.attributes["sentry.release"] }).to eq([ "abc123", "abc123" ])
  end

  it "計装が設定した属性を保持する" do
    tracer_provider.tracer("test").in_span("some span", attributes: { "gen_ai.system" => "anthropic" }) { }

    expect(exporter.finished_spans.first.attributes).to include(
      "gen_ai.system" => "anthropic",
      "sentry.release" => "abc123"
    )
  end
end
