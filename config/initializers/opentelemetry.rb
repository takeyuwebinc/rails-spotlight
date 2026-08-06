# frozen_string_literal: true

# アプリと LLM 呼び出し（RubyLLM）を OpenTelemetry で計装する。
# トレースの送信先は Sentry の OTLP 取り込みで、エクスポータの登録は
# Sentry 初期化後に行う（config/initializers/sentry.rb を参照。initializer の
# 辞書順により本ファイルが先に実行される）。そのため SDK が既定で立てる
# localhost 宛 OTLP エクスポータはここで無効化しておく。
if Rails.env.development? || Rails.env.production?
  ENV["OTEL_TRACES_EXPORTER"] ||= "none"

  OpenTelemetry::SDK.configure do |c|
    c.service_name = "spotlight-rails"
    # Sentry の OTLP 取り込みは resource 属性 deployment.environment.name を
    # スパン属性 sentry.environment にバックフィルする。これを付けないと
    # トレースに環境が入らず、development と production を分離できない。
    # エラーイベント・ログの環境は SDK が RAILS_ENV から自動で設定するため、
    # 出所を揃える目的でここでも Rails.env を使う。
    c.resource = OpenTelemetry::SDK::Resources::Resource.create(
      "deployment.environment.name" => Rails.env.to_s
    )
    c.use "OpenTelemetry::Instrumentation::Rails"
    c.use "OpenTelemetry::Instrumentation::Faraday"
    c.use "OpenTelemetry::Instrumentation::Net::HTTP"
    # プロンプト・出力本文をスパンに含めるかは環境変数
    # OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT で制御する。
    # 計装 gem の既定は含めないため、開発は .devcontainer/devcontainer.json、
    # 本番は config/deploy.yml で明示的に true を与えている
    c.use "OpenTelemetry::Instrumentation::RubyLLM"
  end
end
