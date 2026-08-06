# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  # テレメトリ（トレース）に紐づける操作主体。{ id:, email:, name: } のハッシュ。
  # 設定は ObservabilityUserContext#set_observability_user から行い、
  # 参照は Observability::UserAttributesSpanProcessor が行う。
  attribute :observability_user
end
