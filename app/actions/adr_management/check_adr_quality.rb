# frozen_string_literal: true

module AdrManagement
  # ADR 本文の決定的ルールチェックを実行し、rule 層の品質評価として記録する。
  # 所見は参考情報であり、ADR の登録・更新の成否には影響しない。
  #
  # 有効な rule 層の評価は常に最新の1件に保つ。旧評価の未処理所見は、
  # 今回のチェックで検出されなくなったものを addressed（修正済み）、
  # 引き続き検出されるものを obsolete（最新評価へ引き継ぎ）で自動クローズする。
  class CheckAdrQuality < ApplicationAction
    # 1ページ相当の目安。ADR 記録原則の「1ページ以内」を文字数で近似する
    MAX_BODY_CHARS = 8_000

    # 根拠の添付を求める効果・倍率表現と、根拠とみなす語。
    # 同一行に根拠語があれば計測済みまたは見込みと明示されたと判定する
    EFFECT_CLAIM_PATTERN = /\d+(?:\.\d+)?\s*倍|大幅に|劇的に|飛躍的に/
    EVIDENCE_PATTERN = /計測|実測|測定|ベンチマーク|出典|見込み|期待|目安/

    # 代替案の見出しとみなす行頭パターン（番号付き・箇条書き・「案N」・見出し）
    ALTERNATIVE_HEADING_PATTERN = /\A\s*(?:案\s*\d|\d+\s*[.．)]|[-*]\s|#+\s)/

    def initialize(adr:, origin:)
      @adr = adr
      @origin = origin
    end

    def perform
      findings = detect_findings
      assessment = nil
      ActiveRecord::Base.transaction do
        close_previous_open_findings(findings)
        assessment = @adr.quality_assessments.create!(
          layer: "rule",
          content_fingerprint: QualityAssessment.fingerprint_for(@adr),
          findings: findings,
          reviewed_at: findings.empty? ? Time.current : nil,
          origin: @origin
        )
      end
      success(assessment)
    end

    private

    def close_previous_open_findings(current_findings)
      current_codes = current_findings.map { |finding| finding["code"] }
      @adr.quality_assessments.rule_layer.pending_review.find_each do |assessment|
        open_codes = assessment.open_findings.map { |finding| finding["code"] }
        resolved = open_codes - current_codes
        assessment.close_open_findings!(result: "addressed", only_codes: resolved) if resolved.any?
        assessment.close_open_findings!(result: "obsolete")
      end
    end

    def detect_findings
      [
        alternatives_findings,
        negative_consequences_finding,
        reevaluation_condition_finding,
        effect_claim_finding,
        body_length_finding
      ].flatten.compact.map(&:stringify_keys)
    end

    def alternatives_findings
      text = @adr.alternatives.to_s
      if text.blank?
        return [ {
          code: "alternatives_missing",
          field: "alternatives",
          message: "代替案が記録されていません。現状維持を含む2案以上と却下理由の記載を検討してください"
        } ]
      end

      findings = []
      if count_alternatives(text) < 2
        findings << {
          code: "alternatives_insufficient",
          field: "alternatives",
          message: "代替案の記載が2案未満に見えます。検討した案を「案N」や箇条書きで分けて記載してください"
        }
      end
      unless text.match?(/現状維持|現状の(?:まま|継続)/)
        findings << {
          code: "status_quo_missing",
          field: "alternatives",
          message: "「現状維持」案の検討が見当たりません。なぜ現状のままでは不十分かを代替案に含めてください"
        }
      end
      findings
    end

    def count_alternatives(text)
      text.lines.count { |line| line.match?(ALTERNATIVE_HEADING_PATTERN) }
    end

    def negative_consequences_finding
      return nil if @adr.consequences.to_s.match?(/ネガティブ|トレードオフ|デメリット|欠点|リスク|犠牲/)

      {
        code: "negative_consequences_missing",
        field: "consequences",
        message: "結果（consequences）にネガティブな影響・トレードオフの記述が見当たりません。" \
                 "ポジティブのみの ADR は不完全です"
      }
    end

    def reevaluation_condition_finding
      lines = condition_lines(@adr.reevaluation_conditions)
      return nil if lines.empty?

      malformed = lines.reject do |line|
        line.match?(/場合|とき|たら|時点/) && line.match?(/検討|見直|再評価|切り替え|移行|廃止|削除/)
      end
      return nil if malformed.empty?

      {
        code: "reevaluation_condition_format",
        field: "reevaluation_conditions",
        message: "再評価条件のうち#{malformed.size}件が「〔観測可能な事実〕になったら〔見直し先〕を検討する」" \
                 "の形式に見えません（例: #{malformed.first.truncate(60)}）。" \
                 "何を見れば発火が分かるかと見直し先を条件に含めてください"
      }
    end

    def condition_lines(text)
      text.to_s.lines.map { |line| line.sub(/\A\s*[-*]\s*/, "").strip }.reject(&:blank?)
    end

    def effect_claim_finding
      claims = %w[context decision consequences].flat_map do |attribute|
        @adr.public_send(attribute).to_s.lines.filter_map do |line|
          match = line.match(EFFECT_CLAIM_PATTERN)
          match[0] if match && !line.match?(EVIDENCE_PATTERN)
        end
      end
      return nil if claims.empty?

      {
        code: "unsupported_effect_claim",
        field: "context, decision, consequences",
        message: "根拠の記載がない効果・倍率表現があります（#{claims.uniq.first(3).join('、')}）。" \
                 "計測・出典を添えるか、未計測なら見込み値であることを明記してください"
      }
    end

    def body_length_finding
      total = QualityAssessment::SOURCE_ATTRIBUTES.sum { |attribute| @adr.public_send(attribute).to_s.length }
      return nil if total <= MAX_BODY_CHARS

      {
        code: "body_too_long",
        field: "context, decision, consequences",
        message: "本文が約#{total}文字あり、1ページ相当の目安（#{MAX_BODY_CHARS}文字）を超えています。" \
                 "長大な調査記録は別文書にし、ADR には決定と要点を残すことを検討してください"
      }
    end
  end
end
