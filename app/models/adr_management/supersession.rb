# frozen_string_literal: true

module AdrManagement
  # 新旧 ADR 間の置換関係。1件の新 ADR が複数の旧 ADR を置き換えられる。
  # 旧 ADR 側は高々1件（置換対象は accepted のみで、置換された時点で
  # superseded になり2度目の置換は起こらない）。
  class Supersession < ApplicationRecord
    belongs_to :superseding_adr, class_name: "AdrManagement::Adr"
    belongs_to :superseded_adr, class_name: "AdrManagement::Adr"

    validates :superseded_adr_id, uniqueness: true
  end
end
