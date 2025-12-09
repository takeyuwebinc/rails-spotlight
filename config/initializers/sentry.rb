# frozen_string_literal: true

Sentry.init do |config|
  config.breadcrumbs_logger = [ :active_support_logger ]
  config.dsn = "https://4c9c655faa3ad26cb0a278bd3c88b1b6@o135775.ingest.us.sentry.io/4510050183479296"
  config.traces_sample_rate = 1.0
  config.send_default_pii = true
  config.enable_logs = true
  config.enabled_patches << :logger
  config.rails.structured_logging.enabled = true

  # テスト環境では無効化
  config.enabled_environments = %w[development production]
end
