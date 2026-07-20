# LLM プロバイダはさくらのAI Engine（OpenAI 互換 API）を使用する。
# 選定理由: ADR 検索の埋め込み API と同一プロバイダで契約・機密性評価
# （国内データセンター処理・学習利用なし）を共有できるため。
RubyLLM.configure do |config|
  config.openai_api_key = Rails.application.credentials.dig(:sakura, :ai_account_token)
  config.openai_api_base = "https://api.ai.sakura.ad.jp/v1"

  # Use the association-based acts_as API (recommended)
  config.use_new_acts_as = true
end
