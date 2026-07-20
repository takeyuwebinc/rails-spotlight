# frozen_string_literal: true

module WorkHour
  # 工数管理ドメインにおける取引先の拡張。識別属性（code・name）は
  # ドメイン横断の共有クライアント（Client）が保持し、本モデルは
  # 共有クライアントへの参照とドメイン固有の関連（projects）のみを持つ。
  class Client < ApplicationRecord
    include SharedClientExtension

    has_many :projects, class_name: "WorkHour::Project", dependent: :nullify

    def self.generate_code_from_name(name)
      return "" if name.blank?

      # Downcase, replace spaces and special chars with hyphens, remove consecutive hyphens
      name
        .downcase
        .gsub(/[^a-z0-9\s-]/, "")
        .gsub(/\s+/, "-")
        .gsub(/-+/, "-")
        .gsub(/^-|-$/, "")
    end
  end
end
