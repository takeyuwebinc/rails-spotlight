# frozen_string_literal: true

# カスタム ActiveRecord Type を登録
Rails.application.config.to_prepare do
  require Rails.root.join("app/types/month_date_type")
end
