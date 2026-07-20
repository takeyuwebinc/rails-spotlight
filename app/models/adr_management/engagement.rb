# frozen_string_literal: true

module AdrManagement
  # 案件。クライアントから受託している継続的な開発対象（例: Fabble）で、
  # ADR の記録先および連番採番の単位となる。
  class Engagement < ApplicationRecord
    belongs_to :client, class_name: "AdrManagement::Client"
    has_many :projects, class_name: "AdrManagement::Project",
      dependent: :restrict_with_error

    validates :code, presence: true, uniqueness: true
    validates :name, presence: true
    validates :max_issued_number,
      numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  end
end
