# frozen_string_literal: true

module Observability
  # 全スパンに Sentry のリリース識別子（sentry.release）を付与する SpanProcessor。
  #
  # Sentry の OTLP 取り込みは、環境については resource 属性
  # deployment.environment.name をスパン属性 sentry.environment へ変換するが
  # （config/initializers/opentelemetry.rb を参照）、リリースには resource 属性
  # からの変換経路がない。resource 属性は取り込み時に resource. が前置されるため、
  # sentry.release という名前で resource に置いても認識されない。
  # そのためスパン属性として直接付与する必要がある。
  #
  # 属性は終了済みのスパンには設定できないため、エクスポータではなく
  # SpanProcessor#on_start で付与する。
  class SentryReleaseSpanProcessor < OpenTelemetry::SDK::Trace::SpanProcessor
    RELEASE_ATTRIBUTE_KEY = "sentry.release"

    def initialize(release)
      super()
      @release = release
    end

    def on_start(span, _parent_context)
      span.set_attribute(RELEASE_ATTRIBUTE_KEY, @release)
    end
  end
end
