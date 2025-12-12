# frozen_string_literal: true

module Admin
  module WorkHour
    class CsvController < BaseController
      def index
      end

      def import_projects
        unless params[:file].present?
          redirect_to admin_work_hour_csv_index_path, alert: "ファイルを選択してください。"
          return
        end

        result = ::WorkHour::CsvImporter.import_projects(params[:file])
        redirect_to admin_work_hour_csv_index_path,
                    notice: "案件をインポートしました。（作成: #{result[:created]}件、更新: #{result[:updated]}件、スキップ: #{result[:skipped]}件）"
      rescue ::WorkHour::CsvImporter::ImportError => e
        redirect_to admin_work_hour_csv_index_path, alert: "インポートエラー: #{e.message}"
      end

      def import_work_entries
        unless params[:file].present?
          redirect_to admin_work_hour_csv_index_path, alert: "ファイルを選択してください。"
          return
        end

        result = ::WorkHour::CsvImporter.import_work_entries(params[:file])
        redirect_to admin_work_hour_csv_index_path,
                    notice: "工数実績をインポートしました。（作成: #{result[:created]}件、スキップ: #{result[:skipped]}件）"
      rescue ::WorkHour::CsvImporter::ImportError => e
        redirect_to admin_work_hour_csv_index_path, alert: "インポートエラー: #{e.message}"
      end

      def export_work_entries
        start_month = Date.parse(params[:start_month] + "-01")
        end_month = Date.parse(params[:end_month] + "-01")

        csv_data = ::WorkHour::CsvExporter.export_work_entries(start_month, end_month, params[:project_id])

        send_data csv_data,
                  filename: "work_entries_#{start_month.strftime('%Y%m')}_#{end_month.strftime('%Y%m')}.csv",
                  type: "text/csv; charset=utf-8"
      end
    end
  end
end
