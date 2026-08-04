# frozen_string_literal: true

module AdrManagement
  # ADR 間の参照関係（参照元 → 参照先、方向付き）。参照元 ADR の本文中の
  # ADR 番号表記から導出され、本文が唯一の情報源となる（手動での関連付けは
  # 行わない）。SyncAdrReferences による同期以外で作成・削除しない。
  # 置換（Supersession）と異なり情報的な弱い関係であり、ADR の削除を妨げない。
  class AdrReference < ApplicationRecord
    belongs_to :source_adr, class_name: "AdrManagement::Adr"
    belongs_to :target_adr, class_name: "AdrManagement::Adr"

    validates :target_adr_id, uniqueness: { scope: :source_adr_id }
  end
end
