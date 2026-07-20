# frozen_string_literal: true

module AdrManagement
  # 案件。クライアントから受託している継続的な開発対象（例: Fabble）で、
  # ADR の記録先および連番採番の単位となる。
  class Engagement < ApplicationRecord
    belongs_to :client, class_name: "AdrManagement::Client"
    has_many :projects, class_name: "AdrManagement::Project",
      dependent: :restrict_with_error
    has_many :adrs, class_name: "AdrManagement::Adr",
      dependent: :restrict_with_error

    validates :code, presence: true, uniqueness: true
    validates :name, presence: true
    validates :max_issued_number,
      numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    # ADR 番号を払い出す。カウンタは払い出しの記録であり減らさないため、
    # 削除された ADR の番号は再利用されない。同時登録の衝突は
    # UNIQUE(engagement_id, number) 制約が最終防衛線となる。
    def issue_next_number!
      with_lock do
        update!(max_issued_number: max_issued_number + 1)
        max_issued_number
      end
    end
  end
end
