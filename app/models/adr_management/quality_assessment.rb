# frozen_string_literal: true

module AdrManagement
  # ADR 品質評価の実施記録。所見（findings）は参考情報であり、ADR の
  # 登録・更新を妨げない。所見ゼロの評価も記録する。理由は
  # (1)「評価済み・問題なし」と「未評価」を区別し所見発生率の分母を
  # 観測可能にするため、(2) llm 層の同一版スキップ（冪等化）が
  # 所見ゼロの記録の存在を前提とするため。
  #
  # 処理は所見単位で記録する。全所見が処理済みになった時点で
  # reviewed_at が立ち、レビューキューから外れる。
  class QualityAssessment < ApplicationRecord
    LAYERS = %w[rule llm].freeze

    # 所見の処理結果。addressed=修正した / dismissed=誤検知として却下 /
    # obsolete=対象 ADR の失効・再評価による自動クローズ。
    # 誤検知率は dismissed の比率で導出するため、自動クローズは
    # dismissed と区別する
    FINDING_RESULTS = %w[addressed dismissed obsolete].freeze

    # 品質評価の対象となる本文フィールド。この内容の指紋
    # （content_fingerprint）が一致する間は「同一版」として扱う
    SOURCE_ATTRIBUTES = %w[
      title context decision consequences alternatives reevaluation_conditions
    ].freeze

    belongs_to :adr, class_name: "AdrManagement::Adr"

    validates :layer, presence: true, inclusion: { in: LAYERS }
    validates :content_fingerprint, presence: true
    validates :origin, presence: true
    validate :findings_must_be_well_formed

    scope :rule_layer, -> { where(layer: "rule") }
    scope :llm_layer, -> { where(layer: "llm") }
    scope :recent_first, -> { order(created_at: :desc, id: :desc) }
    scope :pending_review, -> { where(reviewed_at: nil) }

    # 品質所見の集計。new_findings は since 以降に作成された評価の所見数、
    # それ以外は現在のスコープ全体の値。誤検知率（dismissed_rate）は
    # 人が処理した所見（addressed + dismissed）に占める dismissed の比率で、
    # 失効による自動クローズ（obsolete）は分母に含めない
    def self.findings_summary(since:)
      new_findings = where(created_at: since..).map { |assessment| Array(assessment.findings).size }.sum
      counts = all.flat_map { |assessment| Array(assessment.findings).map { |f| f["review_result"] } }.tally
      addressed = counts["addressed"].to_i
      dismissed = counts["dismissed"].to_i
      reviewed = addressed + dismissed
      {
        new_findings: new_findings,
        open_findings: counts[nil].to_i,
        addressed: addressed,
        dismissed: dismissed,
        obsolete: counts["obsolete"].to_i,
        dismissed_rate: reviewed.zero? ? nil : dismissed.to_f / reviewed
      }
    end

    def self.fingerprint_for(adr)
      Digest::SHA256.hexdigest(
        SOURCE_ATTRIBUTES.map { |attribute| adr.public_send(attribute).to_s }.join("\x1F")
      )
    end

    def open_findings
      Array(findings).select { |finding| finding["review_result"].blank? }
    end

    # 指定コードの未処理所見に処理結果を記録する
    def resolve_finding!(code, result:)
      close_open_findings!(result: result, only_codes: [ code ])
    end

    # 未処理所見をまとめて処理する。only_codes 指定時は該当コードのみ。
    # 全所見が処理済みになったら reviewed_at を立てる
    def close_open_findings!(result:, only_codes: nil)
      raise ArgumentError, "invalid result: #{result}" unless FINDING_RESULTS.include?(result)

      updated = Array(findings).map do |finding|
        next finding if finding["review_result"].present?
        next finding if only_codes && !only_codes.include?(finding["code"])

        finding.merge("review_result" => result)
      end
      assign_attributes(findings: updated)
      self.reviewed_at ||= Time.current if updated.none? { |finding| finding["review_result"].blank? }
      save!
    end

    private

    def findings_must_be_well_formed
      unless findings.is_a?(Array)
        errors.add(:findings, :invalid)
        return
      end

      findings.each do |finding|
        unless finding.is_a?(Hash) && finding["code"].present? && finding["message"].present?
          errors.add(:findings, :invalid)
          break
        end
        if finding["review_result"].present? && !FINDING_RESULTS.include?(finding["review_result"])
          errors.add(:findings, :invalid)
          break
        end
      end
    end
  end
end
