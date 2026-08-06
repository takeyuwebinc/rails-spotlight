# frozen_string_literal: true

# テスト環境では config/initializers/sentry.rb が require しないため明示する
require Rails.root.join("lib/observability/user_attributes_span_processor")

module ObservabilityUserContext
  extend ActiveSupport::Concern

  private

  # 認証確定後に呼び出し、以降のテレメトリを操作主体に紐づける。
  # - エラー・ログ: Sentry.set_user（scope が LogEvent へ user.* を自動付与）
  # - トレース: Current 経由で UserAttributesSpanProcessor が以降の全スパンへ付与。
  #   認証前に開始済みの現在スパン（リクエストのスパン）へはここで直接付与する
  def set_observability_user(id:, email: nil, name: nil)
    user = { id: id, email: email, name: name }.compact
    Current.observability_user = user
    Sentry.set_user(id: user[:id], email: user[:email], username: user[:name])
    Observability::UserAttributesSpanProcessor.apply(OpenTelemetry::Trace.current_span, user)
  end
end
