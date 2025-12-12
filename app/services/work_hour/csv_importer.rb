# frozen_string_literal: true

require "csv"

module WorkHour
  class CsvImporter
    class ImportError < StandardError; end

    class << self
      def import_projects(file)
        created = 0
        updated = 0
        skipped = 0

        parse_csv(file).each do |row|
          project_code = row["プロジェクトコード"]&.strip
          project_name = row["プロジェクト名"]&.strip

          next if project_code.blank? || project_name.blank?

          # クライアントの検索または作成
          client = find_or_create_client(row["発注元"]&.strip)

          # 案件の検索または作成
          project = ::WorkHour::Project.find_or_initialize_by(code: project_code)
          is_new = project.new_record?

          project.assign_attributes(
            name: project_name,
            client: client,
            color: row["カラー"]&.strip || "#6366f1",
            start_date: parse_date(row["期間from"]),
            end_date: parse_date(row["期間to"]),
            status: parse_status(row["運用ステータス"])
          )

          if project.save
            is_new ? created += 1 : updated += 1
          else
            skipped += 1
          end
        end

        { created: created, updated: updated, skipped: skipped }
      end

      def import_work_entries(file)
        created = 0
        skipped = 0

        parse_csv(file).each do |row|
          target_month_str = row["対象月"]&.strip
          worked_on_str = row["工数登録日"]&.strip
          minutes_str = row["工数実績(分)"]&.strip

          next if target_month_str.blank? || worked_on_str.blank? || minutes_str.blank?

          target_month = parse_month(target_month_str)
          worked_on = parse_date(worked_on_str)
          minutes = minutes_str.to_i

          next if target_month.nil? || worked_on.nil? || minutes <= 0

          # 案件の検索
          project_code = row["プロジェクトコード"]&.strip
          project = project_code.present? ? ::WorkHour::Project.find_by(code: project_code) : nil

          work_entry = ::WorkHour::WorkEntry.new(
            project: project,
            target_month: target_month,
            worked_on: worked_on,
            description: row["業務内容"]&.strip,
            minutes: minutes
          )

          if work_entry.save
            created += 1
          else
            skipped += 1
          end
        end

        { created: created, skipped: skipped }
      end

      private

      def parse_csv(file)
        content = file.read.force_encoding("UTF-8")
        # BOM除去
        content = content.sub(/\A\xEF\xBB\xBF/, "")
        CSV.parse(content, headers: true, liberal_parsing: true)
      rescue => e
        raise ImportError, "CSVファイルの解析に失敗しました: #{e.message}"
      end

      def find_or_create_client(name)
        return nil if name.blank?

        client = ::WorkHour::Client.find_by(name: name)
        return client if client

        code = ::WorkHour::Client.generate_code_from_name(name)
        code = "client-#{SecureRandom.hex(4)}" if code.blank?

        ::WorkHour::Client.create!(code: code, name: name)
      end

      def parse_date(str)
        return nil if str.blank?

        # "2025年01月01日" or "2025/01/01" or "2025-01-01"
        if str.match(/(\d{4})年(\d{1,2})月(\d{1,2})日/)
          Date.new(::Regexp.last_match(1).to_i, ::Regexp.last_match(2).to_i, ::Regexp.last_match(3).to_i)
        else
          Date.parse(str)
        end
      rescue
        nil
      end

      def parse_month(str)
        return nil if str.blank?

        # "2025年01月"
        if str.match(/(\d{4})年(\d{1,2})月/)
          Date.new(::Regexp.last_match(1).to_i, ::Regexp.last_match(2).to_i, 1)
        else
          Date.parse(str + "-01")
        end
      rescue
        nil
      end

      def parse_status(str)
        case str&.strip
        when "運用中"
          "active"
        when "終了"
          "closed"
        else
          "active"
        end
      end
    end
  end
end
