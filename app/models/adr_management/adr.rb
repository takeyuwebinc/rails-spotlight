# frozen_string_literal: true

module AdrManagement
  # アーキテクチャ決定記録（ADR）。案件（Engagement）に対して記録され、
  # 案件ごとの連番（number）で識別される。番号は採番カウンタが払い出し、
  # 削除された番号は再利用されない。
  class Adr < ApplicationRecord
    STATUSES = %w[proposed accepted rejected deprecated superseded].freeze
    CONFIDENCES = %w[high medium low].freeze

    # 更新操作で許可されるステータス遷移。accepted → superseded は
    # 置換の一体操作によってのみ行われるため、ここには含めない。
    ALLOWED_STATUS_TRANSITIONS = {
      "proposed" => %w[accepted rejected],
      "accepted" => %w[deprecated]
    }.freeze

    # 版履歴のスナップショットとして保存する項目
    SNAPSHOT_ATTRIBUTES = %w[
      engagement_id project_id number title status confidence decided_on
      context decision consequences alternatives reevaluation_conditions
      reference_links
    ].freeze

    belongs_to :engagement, class_name: "AdrManagement::Engagement"
    belongs_to :project, class_name: "AdrManagement::Project", optional: true

    # 置換関係を持つ ADR は削除できないため、restrict を revisions の
    # dependent より先に定義して破棄前の防壁とする
    has_many :supersessions_as_superseding, class_name: "AdrManagement::Supersession",
      foreign_key: :superseding_adr_id, inverse_of: :superseding_adr,
      dependent: :restrict_with_error
    has_one :supersession_as_superseded, class_name: "AdrManagement::Supersession",
      foreign_key: :superseded_adr_id, inverse_of: :superseded_adr,
      dependent: :restrict_with_error
    has_many :superseded_adrs, through: :supersessions_as_superseding,
      source: :superseded_adr
    has_one :superseding_adr, through: :supersession_as_superseded,
      source: :superseding_adr

    has_many :revisions, class_name: "AdrManagement::AdrRevision",
      dependent: :destroy
    has_many :chunks, class_name: "AdrManagement::AdrChunk",
      dependent: :delete_all
    has_many :reevaluation_checks, class_name: "AdrManagement::ReevaluationCheck",
      dependent: :delete_all

    validates :number, presence: true, uniqueness: { scope: :engagement_id }
    validates :title, presence: true
    validates :status, presence: true, inclusion: { in: STATUSES }
    validates :confidence, presence: true, inclusion: { in: CONFIDENCES }
    validates :decided_on, presence: true
    validates :context, presence: true
    validates :decision, presence: true
    validates :consequences, presence: true
    validate :project_belongs_to_same_engagement

    scope :accepted, -> { where(status: "accepted") }

    # ADR 番号の表示名（例: SPOTLIGHT-RAILS-12）。案件 code は照合用に
    # 小文字で保持し、ADR 番号としての表示時のみ大文字にする。
    def display_number
      "#{engagement.code.upcase}-#{number}"
    end

    def supersession_involved?
      supersessions_as_superseding.exists? || supersession_as_superseded.present?
    end

    def snapshot_attributes
      attributes.slice(*SNAPSHOT_ATTRIBUTES)
    end

    def record_revision!(change_type:, origin:, before: nil, changed_fields: nil)
      revisions.create!(
        change_type: change_type,
        origin: origin,
        snapshot: before,
        changed_fields: changed_fields
      )
    end

    private

    def project_belongs_to_same_engagement
      return if project.nil? || project.engagement_id == engagement_id

      errors.add(:project, :invalid)
    end
  end
end
