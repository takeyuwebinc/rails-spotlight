# frozen_string_literal: true

module ContentAgent
  # エージェントが提案した掲載内容への変更。承認ゲートの中核であり、
  # 掲載内容のテーブルを変更してよいのは、この保留変更を承認済みへ
  # 遷移させる適用処理（ApplyPendingChange）のみ。ツール実行や LLM の
  # 判断が直接掲載内容を変更しないことで、「承認した内容だけが反映される」
  # を構造的に保証する。
  class PendingChange < ApplicationRecord
    class InvalidTransition < StandardError; end

    TARGET_TYPES = %w[Project SpeakingEngagement UsesItem Slide].freeze

    # 新規作成の提案に最低限含まれるべき属性。公開状態（published_at /
    # published）を必須に含めるのは、作成時の公開状態を管理者に確認して
    # からプレビューに載せる運用のため。
    REQUIRED_CREATE_ATTRIBUTES = {
      "Project" => %w[title description icon color technologies published_at],
      "SpeakingEngagement" => %w[title slug event_name event_date published],
      "UsesItem" => %w[name slug category description published],
      "Slide" => %w[content]
    }.freeze

    belongs_to :chat
    belongs_to :message, optional: true

    enum :status, {
      pending: "pending",
      approved: "approved",
      rejected: "rejected",
      superseded: "superseded",
      failed: "failed"
    }, default: "pending"

    enum :operation, {
      create: "create",
      update: "update",
      toggle_publication: "toggle_publication"
    }, prefix: :operation

    validates :target_type, inclusion: { in: TARGET_TYPES }
    validates :target_id, presence: true, unless: :operation_create?
    validate :payload_must_be_present
    validate :payload_must_include_required_attributes, if: :operation_create?

    scope :ordered, -> { order(:created_at) }

    def reject!
      transition!(to: :rejected, from: %w[pending])
    end

    def supersede!
      transition!(to: :superseded, from: %w[pending failed])
    end

    def mark_applied!
      transition!(to: :approved, from: %w[pending]) { self.applied_at = Time.current }
    end

    def mark_apply_failed!(error_message)
      transition!(to: :failed, from: %w[pending]) { self.apply_error = error_message }
    end

    def target_record
      return nil if target_id.blank?

      target_type.constantize.find_by(id: target_id)
    end

    private

    def transition!(to:, from:)
      raise InvalidTransition, "#{status} から #{to} へは遷移できません" unless from.include?(status)

      yield if block_given?
      self.status = to
      save!
    end

    def payload_must_be_present
      errors.add(:payload, "を指定してください") if payload.blank?
    end

    def payload_must_include_required_attributes
      required = REQUIRED_CREATE_ATTRIBUTES[target_type]
      return if required.blank? || payload.blank?

      missing = required.reject { |key| payload.key?(key) && !payload[key].nil? }
      errors.add(:payload, "に必須属性が不足しています: #{missing.join(', ')}") if missing.any?

      return unless target_type == "Slide" && payload["content"].present?

      # Slide の公開状態は frontmatter の published_date で表現するため、
      # 取り込み失敗を適用時まで遅らせず提案時点で検出する
      errors.add(:payload, "の markdown frontmatter に published_date が必要です") unless payload["content"].match?(/^published_date:/)
    end
  end
end
