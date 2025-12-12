# frozen_string_literal: true

module Tools
  class FindWorkHourProjectTool < MCP::Tool
    description "Find a work hour project by code or name"

    input_schema(
      properties: {
        query: {
          type: "string",
          description: "Search keyword (code or name)"
        }
      },
      required: [ "query" ]
    )

    def self.call(query:, server_context:)
      project = find_project(query)

      if project
        client_name = project.client&.name || "(no client)"
        period = format_period(project.start_date, project.end_date)

        estimates_text = format_estimates(project)

        MCP::Tool::Response.new([ {
          type: "text",
          text: "Found project:\n" \
                "- Code: #{project.code}\n" \
                "- Name: #{project.name}\n" \
                "- Client: #{client_name}\n" \
                "- Color: #{project.color}\n" \
                "- Status: #{project.status}\n" \
                "- Period: #{period}\n" \
                "#{estimates_text}"
        } ])
      else
        MCP::Tool::Response.new([ {
          type: "text",
          text: "Project not found for query: #{query}"
        } ])
      end
    rescue => e
      MCP::Tool::Response.new([ {
        type: "text",
        text: "Error finding project: #{e.message}"
      } ])
    end

    def self.find_project(query)
      # 1. Exact code match
      project = WorkHour::Project.find_by(code: query)
      return project if project

      # 2. Partial code match (prefix)
      project = WorkHour::Project.where("code LIKE ?", "#{query}%").first
      return project if project

      # 3. Name partial match
      WorkHour::Project.where("name LIKE ?", "%#{query}%").first
    end

    def self.format_period(start_date, end_date)
      return "Not set" if start_date.nil? && end_date.nil?

      start_str = start_date&.strftime("%Y-%m-%d") || "?"
      end_str = end_date&.strftime("%Y-%m-%d") || "?"
      "#{start_str} - #{end_str}"
    end

    def self.format_estimates(project)
      # Get upcoming 3 months of estimates
      current_month = Date.today.beginning_of_month
      end_month = current_month + 2.months

      estimates = project.monthly_estimates
                         .where(year_month: current_month..end_month)
                         .order(:year_month)

      return "" if estimates.empty?

      estimates_list = estimates.map do |estimate|
        "  - #{estimate.year_month.strftime('%Y-%m')}: #{estimate.estimated_hours}h"
      end.join("\n")

      "- Monthly Estimates (upcoming):\n#{estimates_list}"
    end
  end
end
