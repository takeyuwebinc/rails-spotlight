# frozen_string_literal: true

module Tools
  class RegisterAdrTool < MCP::Tool
    extend AdrManagementToolSupport

    description "Register an ADR (architecture decision record) to an engagement. " \
                "The number is issued automatically per engagement. " \
                "To replace existing accepted decisions, pass superseded_numbers: the new ADR is registered as accepted " \
                "and the old ADRs are atomically marked superseded with the relation recorded."

    input_schema(
      properties: {
        engagement_code: {
          type: "string",
          description: "Code of the engagement to record the ADR against"
        },
        title: {
          type: "string",
          description: "One-line title identifying the decision"
        },
        status: {
          type: "string",
          enum: [ "proposed", "accepted" ],
          description: "Initial status: accepted for decisions already made, proposed for proposals (default: accepted)"
        },
        confidence: {
          type: "string",
          enum: AdrManagement::Adr::CONFIDENCES,
          description: "Confidence of the decision"
        },
        decided_on: {
          type: "string",
          description: "Decision date (YYYY-MM-DD, default: today)"
        },
        context: {
          type: "string",
          description: "Context: current problems and constraints"
        },
        decision: {
          type: "string",
          description: "The decision (implementation policy)"
        },
        consequences: {
          type: "string",
          description: "Consequences: positive and negative impacts / trade-offs"
        },
        alternatives: {
          type: "string",
          description: "Alternatives considered and why they were rejected"
        },
        reevaluation_conditions: {
          type: "string",
          description: "Conditions under which the decision should be re-evaluated"
        },
        reference_links: {
          type: "string",
          description: "Reference links"
        },
        project_name: {
          type: "string",
          description: "Name of the project (period) in which the decision was made"
        },
        superseded_numbers: {
          type: "array",
          items: { type: "integer" },
          description: "Numbers of accepted ADRs in the same engagement that this ADR supersedes"
        }
      },
      required: [ "engagement_code", "title", "confidence", "context", "decision", "consequences" ]
    )

    def self.call(engagement_code:, title:, confidence:, context:, decision:, consequences:,
                  status: "accepted", decided_on: nil, alternatives: nil,
                  reevaluation_conditions: nil, reference_links: nil, project_name: nil,
                  superseded_numbers: [], server_context:)
      engagement = find_engagement_or_error(engagement_code)
      return engagement if engagement.is_a?(MCP::Tool::Response)

      decided_date, error = parse_date_or_error(decided_on, "decided_on")
      return error if error

      project = nil
      if project_name.present?
        project = engagement.projects.find_by(name: project_name)
        unless project
          return error_response(AdrManagement::OperationError.build(
            kind: :master_not_found,
            param: "project_name",
            message: "プロジェクト「#{project_name}」が案件「#{engagement.code}」に存在しません",
            next_action: "list_adr_projects_tool で表記揺れがないか確認し、" \
                         "存在しなければ create_adr_project_tool で作成してください"
          ))
        end
      end

      result = AdrManagement::RegisterAdr.perform(
        engagement: engagement,
        attributes: {
          title: title,
          status: status,
          confidence: confidence,
          decided_on: decided_date || Date.current,
          context: context,
          decision: decision,
          consequences: consequences,
          alternatives: alternatives,
          reevaluation_conditions: reevaluation_conditions,
          reference_links: reference_links,
          project: project
        },
        origin: origin_from(server_context),
        superseded_numbers: superseded_numbers
      )

      return error_response(result.errors) if result.failure?

      adr = result.data
      superseded_note = if adr.superseded_adrs.any?
        "\n- Superseded: #{adr.superseded_adrs.map(&:display_number).join(', ')}"
      else
        ""
      end
      text_response(
        "ADR registered successfully:\n" \
        "- Number: #{adr.display_number}\n" \
        "- Title: #{adr.title}\n" \
        "- Status: #{adr.status}#{superseded_note}"
      )
    rescue => e
      text_response("Error registering ADR: #{e.message}")
    end
  end
end
