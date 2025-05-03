# This initializer is no longer needed as we're not using ActionText anymore.
# The content is now stored directly in the articles.content column as HTML.

# # Disable HTML sanitization for ActionText
# Rails.application.config.to_prepare do
#   # ActionTextのサニタイザーを設定
#   ActionText::ContentHelper.sanitizer = Rails::HTML::Sanitizer.new do |html|
#     # 何もサニタイズしない（HTMLをそのまま返す）
#     html
#   end
# end
