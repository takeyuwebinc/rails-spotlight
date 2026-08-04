# frozen_string_literal: true

module AdrManagement
  # 参照同期の結果。referenced_adrs は本文から解決できた参照先 ADR、
  # unknown_numbers は案件 code は実在するが連番が存在しない表記
  # （書き手への警告対象）
  ReferenceSyncResult = Data.define(:referenced_adrs, :unknown_numbers)
end
