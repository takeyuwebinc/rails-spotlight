# frozen_string_literal: true

module Tools
  class CreateAdrClientTool < MCP::Tool
    extend AdrManagementToolSupport

    description "Create an ADR management client. " \
                "If a shared client with the same code already exists (e.g. registered by work hour management), " \
                "it is reused as the same entity."

    input_schema(
      properties: {
        code: {
          type: "string",
          description: "Client code (unique identifier across domains)"
        },
        name: {
          type: "string",
          description: "Client name"
        }
      },
      required: [ "code", "name" ]
    )

    def self.call(code:, name:, server_context:)
      shared_existed = ::Client.exists?(code: code)
      client = AdrManagement::Client.new(code: code, name: name)

      if client.save
        note = shared_existed ? "\n（既存の共有クライアントに接続しました。他ドメインの登録と同一実体になります）" : ""
        text_response(
          "Client created successfully:\n" \
          "- Code: #{client.code}\n" \
          "- Name: #{client.name}#{note}"
        )
      else
        error_response(client.errors.map do |error|
          AdrManagement::OperationError.build(
            kind: :invalid_input,
            param: error.attribute.to_s,
            message: error.full_message,
            next_action: "list_adr_clients_tool で既存クライアントを確認してください"
          )
        end)
      end
    rescue => e
      text_response("Error creating client: #{e.message}")
    end
  end
end
