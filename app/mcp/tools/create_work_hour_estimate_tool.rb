# frozen_string_literal: true

module Tools
  class CreateWorkHourEstimateTool < MCP::Tool
    description "Create a new work hour estimate for a project"

    input_schema(
      properties: {
        project_code: {
          type: "string",
          description: "Project code"
        },
        year_month: {
          type: "string",
          description: "Target month (YYYY-MM)"
        },
        estimated_hours: {
          type: "number",
          description: "Estimated hours for the month"
        }
      },
      required: [ "project_code", "year_month", "estimated_hours" ]
    )

    def self.call(project_code:, year_month:, estimated_hours:, server_context:)
      # Find project
      project = WorkHour::Project.find_by(code: project_code)
      unless project
        return MCP::Tool::Response.new([ {
          type: "text",
          text: "Error: Project with code '#{project_code}' not found."
        } ])
      end

      # Parse year_month
      month_date = Date.parse("#{year_month}-01")

      # Check for duplicate
      if WorkHour::ProjectMonthlyEstimate.exists?(project: project, year_month: month_date)
        return MCP::Tool::Response.new([ {
          type: "text",
          text: "Error: Estimate for #{project_code} in #{year_month} already exists. Use the admin panel to update."
        } ])
      end

      estimate = WorkHour::ProjectMonthlyEstimate.new(
        project: project,
        year_month: month_date,
        estimated_hours: estimated_hours
      )

      if estimate.save
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Estimate created successfully:\n" \
                "- Project: #{project.name} (#{project.code})\n" \
                "- Month: #{year_month}\n" \
                "- Hours: #{estimated_hours}h"
        } ])
      else
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Error: #{estimate.errors.full_messages.join(', ')}"
        } ])
      end
    rescue => e
      MCP::Tool::Response.new([ {
        type: "text",
        text: "Error creating estimate: #{e.message}"
      } ])
    end
  end
end
