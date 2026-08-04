# frozen_string_literal: true

module AdrManagement
  # ADR 本文中の ADR 番号表記から他 ADR への参照を抽出し、参照テーブルを
  # 本文と一致する状態に置き換える（既存参照の削除と再作成）。本文が参照の
  # 唯一の情報源であるため、本文の保存と同一トランザクション内で呼び出し、
  # 本文と参照テーブルがずれたまま保存が成功することを防ぐ。自己参照は
  # 記録しない。
  class SyncAdrReferences < ApplicationAction
    def initialize(adr:)
      @adr = adr
    end

    def perform
      texts = Adr::REFERENCE_SOURCE_ATTRIBUTES.map { |attribute| @adr.public_send(attribute) }
      resolution = Adr.resolve_text_references(*texts)
      targets = resolution[:references].values.uniq.reject { |target| target.id == @adr.id }

      @adr.outgoing_references.delete_all
      targets.each { |target| @adr.outgoing_references.create!(target_adr: target) }

      success(
        ReferenceSyncResult.new(
          referenced_adrs: targets,
          unknown_numbers: resolution[:unknown_numbers]
        )
      )
    end
  end
end
