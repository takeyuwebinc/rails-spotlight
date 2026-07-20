# frozen_string_literal: true

module AdrManagement
  # ADR の再評価条件に対する点検の記録。条件がまだ満たされていない（no_trigger）か、
  # 満たされた疑いがある（suspected）かの観測を、点検のたびに追記する。
  # 版履歴（AdrRevision）には記録しない。点検は ADR の内容を一切変更しない
  # 業務イベントであり、変更内容の確認・復元を目的とする版履歴に混ぜると
  # 双方の照会を汚すため、保存先を分離している。
  class ReevaluationCheck < ApplicationRecord
    RESULTS = %w[no_trigger suspected].freeze

    belongs_to :adr, class_name: "AdrManagement::Adr"

    validates :checked_on, presence: true
    validates :result, presence: true, inclusion: { in: RESULTS }
    validates :origin, presence: true
    # 観測内容のない発火疑いはレポートの根拠にならないため、メモを必須とする
    validates :note, presence: true, if: :suspected?

    scope :recent_first, -> { order(checked_on: :desc, id: :desc) }

    # 指定日数以内（本日から遡って days 日より新しい checked_on）の点検記録を
    # 持つ ADR の id 一覧。ちょうど days 日前の点検は「期限切れ」として含めない
    def self.adr_ids_checked_within(days)
      where("checked_on > ?", Date.current - days).distinct.pluck(:adr_id)
    end

    # 最新（checked_on 降順・同日なら id 降順）の点検結果が result である
    # ADR の id 一覧
    def self.adr_ids_with_latest_result(result)
      where(result: result).where(<<~SQL.squish).distinct.pluck(:adr_id)
        NOT EXISTS (
          SELECT 1 FROM adr_management_reevaluation_checks newer
          WHERE newer.adr_id = adr_management_reevaluation_checks.adr_id
            AND (newer.checked_on > adr_management_reevaluation_checks.checked_on
              OR (newer.checked_on = adr_management_reevaluation_checks.checked_on
                AND newer.id > adr_management_reevaluation_checks.id))
        )
      SQL
    end

    def suspected?
      result == "suspected"
    end
  end
end
