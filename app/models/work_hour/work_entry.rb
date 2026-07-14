# frozen_string_literal: true

module WorkHour
  class WorkEntry < ApplicationRecord
    belongs_to :project, class_name: "WorkHour::Project", optional: true

    validates :worked_on, presence: true
    validates :target_month, presence: true
    validates :minutes, presence: true, numericality: { only_integer: true, greater_than: 0 }

    # month_fieldから送信される "YYYY-MM" 形式を Date に変換
    attribute :target_month, :month_date

    scope :for_month, ->(year_month) { where(target_month: year_month.beginning_of_month) }
    scope :for_date, ->(date) { where(worked_on: date) }
    scope :for_period, ->(start_month, end_month) {
      where(target_month: start_month.beginning_of_month..end_month.beginning_of_month)
    }

    # 案件IDごとの実績分数合計。案件ごとに逐次集計するとN+1になるため、
    # 全案件分を1クエリでまとめて返す。案件未指定の実績はどの案件にも属さないので除外する。
    # 実績のない案件は0を返す。
    def self.total_minutes_by_project
      Hash.new(0).merge(where.not(project_id: nil).group(:project_id).sum(:minutes))
    end

    # 指定案件について、対象月ごとの実績分数合計を1クエリで返す。
    def self.total_minutes_by_month(project)
      Hash.new(0).merge(where(project: project).group(:target_month).sum(:minutes))
    end

    def hours
      minutes.to_f / 60
    end

    def project_name
      project&.name || "その他"
    end

    def project_code
      project&.code || ""
    end

    def client_name
      project&.client&.name || ""
    end

    def client_code
      project&.client&.code || ""
    end
  end
end
