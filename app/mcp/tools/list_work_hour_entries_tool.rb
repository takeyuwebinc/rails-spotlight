# frozen_string_literal: true

module Tools
  class ListWorkHourEntriesTool < MCP::Tool
    description "List work hour entries with optional filtering"

    input_schema(
      properties: {
        project_code: {
          type: "string",
          description: "Filter by project code"
        },
        start_date: {
          type: "string",
          description: "Filter from date (YYYY-MM-DD)"
        },
        end_date: {
          type: "string",
          description: "Filter to date (YYYY-MM-DD)"
        },
        target_month: {
          type: "string",
          description: "Filter by target month (YYYY-MM)"
        }
      },
      required: []
    )

    def self.call(project_code: nil, start_date: nil, end_date: nil, target_month: nil, server_context:)
      entries = WorkHour::WorkEntry.includes(:project)

      # Filter by project
      if project_code.present?
        project = WorkHour::Project.find_by(code: project_code)
        entries = entries.where(project: project) if project
      end

      # Filter by target month
      if target_month.present?
        month_date = Date.parse("#{target_month}-01")
        entries = entries.for_month(month_date)
      end

      # Filter by date range
      if start_date.present?
        entries = entries.where("worked_on >= ?", Date.parse(start_date))
      end

      if end_date.present?
        entries = entries.where("worked_on <= ?", Date.parse(end_date))
      end

      entries = entries.order(:worked_on, :id)

      if entries.any?
        entry_list = entries.map do |entry|
          project_display = entry.project&.code || "その他"
          "- #{entry.worked_on.strftime('%Y-%m-%d')} #{project_display}: #{entry.description} (#{format_time(entry.minutes)})"
        end.join("\n")

        total_minutes = entries.sum(:minutes)
        total_text = "Total: #{format_time(total_minutes)}"

        MCP::Tool::Response.new([ {
          type: "text",
          text: "Found #{entries.count} entries:\n#{entry_list}\n\n#{total_text}"
        } ])
      else
        MCP::Tool::Response.new([ {
          type: "text",
          text: "No entries found with the specified criteria."
        } ])
      end
    rescue => e
      MCP::Tool::Response.new([ {
        type: "text",
        text: "Error listing entries: #{e.message}"
      } ])
    end

    def self.format_time(minutes)
      hours = minutes / 60
      mins = minutes % 60
      "#{hours}h #{mins}m"
    end
  end
end
