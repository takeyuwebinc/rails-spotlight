# frozen_string_literal: true

module Tools
  class UpdateAdrTool < MCP::Tool
    extend AdrManagementToolSupport

    description "Update an ADR's content and/or status. " \
                "Allowed status transitions: proposed→accepted, proposed→rejected, accepted→deprecated. " \
                "To supersede an accepted decision, use register_adr_tool with superseded_numbers instead."

    input_schema(
      properties: {
        engagement_code: {
          type: "string",
          description: "Code of the engagement the ADR belongs to"
        },
        number: {
          type: "integer",
          description: "ADR number within the engagement"
        },
        title: { type: "string", description: "New title" },
        status: {
          type: "string",
          enum: [ "accepted", "rejected", "deprecated" ],
          description: "New status (must follow the allowed transitions)"
        },
        confidence: {
          type: "string",
          enum: AdrManagement::Adr::CONFIDENCES,
          description: "New confidence"
        },
        decided_on: { type: "string", description: "New decision date (YYYY-MM-DD)" },
        context: { type: "string", description: "New context" },
        decision: { type: "string", description: "New decision text" },
        consequences: { type: "string", description: "New consequences" },
        alternatives: { type: "string", description: "New alternatives" },
        reevaluation_conditions: { type: "string", description: "New re-evaluation conditions" },
        reference_links: { type: "string", description: "New reference links" },
        project_name: { type: "string", description: "Name of the project (period) within the same engagement" }
      },
      required: [ "engagement_code", "number" ]
    )

    def self.call(engagement_code:, number:, server_context:, **attributes)
      engagement = find_engagement_or_error(engagement_code)
      return engagement if engagement.is_a?(MCP::Tool::Response)

      adr = engagement.adrs.find_by(number: number)
      unless adr
        return error_response(AdrManagement::OperationError.build(
          kind: :master_not_found,
          param: "number",
          message: "ADR #{adr_number_label(engagement, number)} が存在しません",
          next_action: "search_adrs_tool で対象案件の ADR 番号を確認してください"
        ))
      end

      updates = attributes.slice(
        :title, :status, :confidence, :context, :decision, :consequences,
        :alternatives, :reevaluation_conditions, :reference_links
      )

      if attributes.key?(:decided_on)
        decided_date, error = parse_date_or_error(attributes[:decided_on], "decided_on")
        return error if error
        updates[:decided_on] = decided_date
      end

      if attributes[:project_name].present?
        project = engagement.projects.find_by(name: attributes[:project_name])
        unless project
          return error_response(AdrManagement::OperationError.build(
            kind: :master_not_found,
            param: "project_name",
            message: "プロジェクト「#{attributes[:project_name]}」が案件「#{engagement.code}」に存在しません",
            next_action: "list_adr_projects_tool で表記揺れがないか確認してください"
          ))
        end
        updates[:project] = project
      end

      if updates.empty?
        return error_response(AdrManagement::OperationError.build(
          kind: :invalid_input,
          param: "attributes",
          message: "更新する項目が指定されていません",
          next_action: "変更したい項目（title・status・context 等）を指定してください"
        ))
      end

      result = AdrManagement::UpdateAdr.perform(
        adr: adr, attributes: updates, origin: origin_from(server_context)
      )
      return error_response(result.errors) if result.failure?

      updated = result.data
      text_response(
        "ADR updated successfully:\n" \
        "- Number: #{updated.display_number}\n" \
        "- Title: #{updated.title}\n" \
        "- Status: #{updated.status}\n" \
        "- Updated fields: #{updates.keys.join(', ')}"
      )
    rescue => e
      text_response("Error updating ADR: #{e.message}")
    end
  end
end
