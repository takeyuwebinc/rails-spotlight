# frozen_string_literal: true

module AdrManagement
  # ADR管理ドメインにおける取引先の拡張。識別属性（code・name）は
  # ドメイン横断の共有クライアント（Client）が保持し、本モデルは
  # 案件（Engagement）の親としてのアンカーと将来の拡張点を担う。
  class Client < ApplicationRecord
    include SharedClientExtension

    has_many :engagements, class_name: "AdrManagement::Engagement",
      dependent: :restrict_with_error
  end
end
