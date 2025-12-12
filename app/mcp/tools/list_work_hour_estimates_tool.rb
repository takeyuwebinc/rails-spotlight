# frozen_string_literal: true

module Tools
  class ListWorkHourEstimatesTool < MCP::Tool
    description "List work hour estimates with optional filtering"

    input_schema(
      properties: {
        project_code: {
          type: "string",
          description: "Filter by project code"
        },
        year_month: {
          type: "string",
          description: "Filter by specific month (YYYY-MM)"
        },
        from_month: {
          type: "string",
          description: "Filter from month (YYYY-MM)"
        },
        to_month: {
          type: "string",
          description: "Filter to month (YYYY-MM)"
        }
      },
      required: []
    )

    def self.call(project_code: nil, year_month: nil, from_month: nil, to_month: nil, server_context:)
      estimates = WorkHour::ProjectMonthlyEstimate.includes(project: :client)

      # Filter by project
      if project_code.present?
        project = WorkHour::Project.find_by(code: project_code)
        estimates = estimates.where(project: project) if project
      end

      # Filter by specific month
      if year_month.present?
        month_date = Date.parse("#{year_month}-01")
        estimates = estimates.where(year_month: month_date)
      elsif from_month.present? || to_month.present?
        # Filter by month range
        from_date = from_month.present? ? Date.parse("#{from_month}-01") : nil
        to_date = to_month.present? ? Date.parse("#{to_month}-01") : nil

        estimates = estimates.where("year_month >= ?", from_date) if from_date
        estimates = estimates.where("year_month <= ?", to_date) if to_date
      end

      estimates = estimates.order(:year_month, "work_hour_projects.code")

      if estimates.any?
        estimate_list = estimates.map do |estimate|
          "- #{estimate.year_month.strftime('%Y-%m')} #{estimate.project.code}: #{estimate.project.name} - #{estimate.estimated_hours}h"
        end.join("\n")

        # Calculate monthly totals
        monthly_totals = estimates.group_by { |e| e.year_month.strftime("%Y-%m") }
                                  .transform_values { |es| es.sum(&:estimated_hours) }
        totals_text = monthly_totals.map { |month, hours| "Total for #{month}: #{hours}h" }.join("\n")

        MCP::Tool::Response.new([ {
          type: "text",
          text: "Found #{estimates.count} estimate(s):\n#{estimate_list}\n\n#{totals_text}"
        } ])
      else
        MCP::Tool::Response.new([ {
          type: "text",
          text: "No estimates found with the specified criteria."
        } ])
      end
    rescue => e
      MCP::Tool::Response.new([ {
        type: "text",
        text: "Error listing estimates: #{e.message}"
      } ])
    end
  end
end
