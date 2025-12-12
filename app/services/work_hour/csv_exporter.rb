# frozen_string_literal: true

require "csv"

module WorkHour
  class CsvExporter
    BOM = "\xEF\xBB\xBF"

    class << self
      def export_work_entries(start_month, end_month, project_id = nil)
        entries = ::WorkHour::WorkEntry
          .includes(:project)
          .for_period(start_month, end_month)
          .order(:target_month, :worked_on)

        entries = entries.where(project_id: project_id) if project_id.present?

        generate_csv(entries)
      end

      private

      def generate_csv(entries)
        BOM + CSV.generate do |csv|
          csv << [ "対象月", "工数登録日", "プロジェクト", "プロジェクトコード", "業務内容", "工数実績(分)" ]

          entries.each do |entry|
            csv << [
              entry.target_month.strftime("%Y年%m月"),
              entry.worked_on.strftime("%Y年%m月%d日"),
              entry.project_name,
              entry.project_code,
              entry.description,
              entry.minutes
            ]
          end
        end
      end
    end
  end
end
