# frozen_string_literal: true

module Tools
  class CreateWorkHourEntryTool < MCP::Tool
    description "Create a new work hour entry"

    input_schema(
      properties: {
        project_code: {
          type: "string",
          description: "Project code (optional, defaults to 'その他')"
        },
        worked_on: {
          type: "string",
          description: "Work date (YYYY-MM-DD)"
        },
        target_month: {
          type: "string",
          description: "Target month (YYYY-MM, defaults to worked_on month)"
        },
        description: {
          type: "string",
          description: "Work description"
        },
        minutes: {
          type: "integer",
          description: "Work time in minutes"
        }
      },
      required: [ "worked_on", "minutes" ]
    )

    def self.call(worked_on:, minutes:, project_code: nil, target_month: nil, description: nil, server_context:)
      # Find project if specified
      project = nil
      if project_code.present?
        project = WorkHour::Project.find_by(code: project_code)
        unless project
          return MCP::Tool::Response.new([ {
            type: "text",
            text: "Error: Project with code '#{project_code}' not found."
          } ])
        end
      end

      # Parse dates
      work_date = Date.parse(worked_on)
      month_date = target_month.present? ? Date.parse("#{target_month}-01") : work_date.beginning_of_month

      entry = WorkHour::WorkEntry.new(
        project: project,
        worked_on: work_date,
        target_month: month_date,
        description: description,
        minutes: minutes
      )

      if entry.save
        project_display = entry.project&.name || "その他"
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Work entry created successfully:\n" \
                "- Date: #{entry.worked_on.strftime('%Y-%m-%d')}\n" \
                "- Project: #{project_display}\n" \
                "- Description: #{entry.description}\n" \
                "- Time: #{format_time(entry.minutes)}"
        } ])
      else
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Error: #{entry.errors.full_messages.join(', ')}"
        } ])
      end
    rescue => e
      MCP::Tool::Response.new([ {
        type: "text",
        text: "Error creating entry: #{e.message}"
      } ])
    end

    def self.format_time(minutes)
      hours = minutes / 60
      mins = minutes % 60
      "#{hours}h #{mins}m"
    end
  end
end
