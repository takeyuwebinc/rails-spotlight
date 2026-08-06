# frozen_string_literal: true

module Observability
  # リクエスト中に開始される全スパンへ操作主体（Current.observability_user）を
  # user.* 属性として付与する SpanProcessor。
  #
  # Sentry はスパン属性 user.id / user.email / user.name をユーザーとして
  # 解釈する（sentry-conventions 定義）。Sentry.set_user はエラーとログにしか
  # 効かず、OTLP で送るスパンには自前で属性を付ける必要がある。
  # スパン属性は親から子へ継承されないため、全スパンの開始時に付与する。
  class UserAttributesSpanProcessor < OpenTelemetry::SDK::Trace::SpanProcessor
    ATTRIBUTE_KEYS = { id: "user.id", email: "user.email", name: "user.name" }.freeze

    # 認証完了前に開始済みのスパン（リクエストのスパン）へ遡って付与する
    # 用途でも使うため、付与処理をクラスメソッドとして公開している。
    def self.apply(span, user)
      return unless user && span.recording?

      ATTRIBUTE_KEYS.each do |key, attribute|
        span.set_attribute(attribute, user[key]) if user[key]
      end
    end

    def on_start(span, _parent_context)
      self.class.apply(span, Current.observability_user)
    end
  end
end
