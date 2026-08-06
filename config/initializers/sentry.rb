# frozen_string_literal: true

require Rails.root.join("lib/observability/log_drop_filter")

Sentry.init do |config|
  config.breadcrumbs_logger = [ :active_support_logger ]
  config.dsn = "https://4c9c655faa3ad26cb0a278bd3c88b1b6@o135775.ingest.us.sentry.io/4510050183479296"
  config.send_default_pii = true
  config.enable_logs = true
  config.enabled_patches << :logger
  config.rails.structured_logging.enabled = true

  # トレースと同様にノイズになるログは送信しない：
  # - Solid アダプタ内部の動作ログ（SpanDropExporter の除外対象と対応）
  # - ヘルスチェックのコントローラログ（Rack 計装の untraced_endpoints と対応）
  config.before_send_log = Observability::LogDropFilter.new(
    /\bSolid(?:Queue|Cache|Cable)\b|\bRails::HealthController\b/
  )

  # テスト環境では無効化
  config.enabled_environments = %w[development production]

  # トレースは OpenTelemetry 計装（config/initializers/opentelemetry.rb）で収集し
  # OTLP で取り込む。SDK ネイティブのトレーシング（traces_sample_rate）とは
  # 併用できないため設定しない。
  if Rails.env.development? || Rails.env.production?
    config.otlp.enabled = true
    # エクスポータは自動設定を使わず、機密キーのマスキングを挟んで下で登録する
    config.otlp.setup_otlp_traces_exporter = false
  end
end

# LLM スパンの内容属性へ filter_parameters を適用してから送信するため、
# OTLP エクスポータをマスキング用ラッパー越しに登録する。
# エンドポイントと認証ヘッダの組み立ては sentry-opentelemetry の自動設定
# （Sentry::OpenTelemetry::OTLPSetup）と同じ方式。自動設定にはエクスポータを
# 差し替える拡張点がないため自前で行っている。
if Rails.env.development? || Rails.env.production?
  require Rails.root.join("lib/observability/gen_ai_content_filter_exporter")
  require Rails.root.join("lib/observability/span_drop_exporter")
  require Rails.root.join("lib/observability/sentry_release_span_processor")
  require Rails.root.join("lib/observability/user_attributes_span_processor")

  # リリースはスパン属性でしか渡せないため、エクスポート前に全スパンへ付与する。
  # 環境（deployment.environment.name）は resource 属性として
  # config/initializers/opentelemetry.rb で設定済み。
  if (release = Sentry.configuration.release)
    OpenTelemetry.tracer_provider.add_span_processor(
      Observability::SentryReleaseSpanProcessor.new(release)
    )
  end

  # 認証済みリクエスト中のスパンへ操作主体（user.* 属性）を付与する。
  # 設定側は app/controllers/concerns/observability_user_context.rb を参照
  OpenTelemetry.tracer_provider.add_span_processor(
    Observability::UserAttributesSpanProcessor.new
  )

  dsn = Sentry.configuration.dsn
  otlp_exporter = OpenTelemetry::Exporter::OTLP::Exporter.new(
    endpoint: "#{dsn.server}#{dsn.otlp_traces_endpoint}",
    headers: { "X-Sentry-Auth" => dsn.generate_auth_header(client: "sentry-ruby.otlp/#{Sentry::VERSION}") }
  )
  OpenTelemetry.tracer_provider.add_span_processor(
    OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
      # Solid アダプタ内部の DB アクセススパンはノイズのため除外してから
      # マスキングを適用する
      Observability::SpanDropExporter.new(
        Observability::GenAiContentFilterExporter.new(otlp_exporter),
        name_prefixes: %w[SolidQueue:: SolidCache:: SolidCable::]
      )
    )
  )
end
