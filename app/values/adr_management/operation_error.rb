# frozen_string_literal: true

module AdrManagement
  # ADR管理の操作エラー。MCP ツールが Coding Agent へ「何が・どの入力で・
  # 次に何をすべきか」を返せるよう、種別・原因パラメータ・推奨アクションを持つ。
  # kind: :master_not_found / :invalid_supersession / :invalid_status_transition /
  #       :invalid_input / :check_not_allowed
  OperationError = Data.define(:kind, :param, :message, :next_action) do
    def self.build(kind:, message:, param: nil, next_action: nil)
      new(kind: kind, param: param, message: message, next_action: next_action)
    end

    def to_s
      message
    end
  end
end
