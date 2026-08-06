# frozen_string_literal: true

module AdrManagement
  # ADR 本文を LLM で評価し、llm 層の品質評価として記録する。
  # 評価観点はルールで判定できない3つ:
  #   1. この ADR がないと AI が誤る具体的な場面を挙げられるか
  #   2. 再評価条件の発火を何を見れば判定できるか（観測可能性）
  #   3. 決定がモデル既知の一般論に終始していないか
  #
  # 所見は参考情報であり、LLM 呼び出しの失敗は評価なしで縮退する
  # （呼び出し元の登録・更新には影響しない）。同一本文（指紋一致）の
  # 評価が既にあれば実行をスキップする（連続更新時の多重評価の防止）。
  #
  # 有効な llm 層の評価は最新の1件に保ち、旧評価の未処理所見は
  # 今回の評価結果との差分で自動クローズする（rule 層と同一の規則）。
  class AssessAdrQuality < ApplicationAction
    FINDING_CODES = %w[
      ai_error_example_weak reevaluation_condition_unobservable generic_knowledge
    ].freeze
    MAX_FINDINGS = 10
    REQUEST_TIMEOUT = 60

    def initialize(adr:, origin:)
      @adr = adr
      @origin = origin
    end

    def perform
      return success(nil) if Adr::RETIRED_STATUSES.include?(@adr.status)

      fingerprint = QualityAssessment.fingerprint_for(@adr)
      existing = @adr.quality_assessments.llm_layer.find_by(content_fingerprint: fingerprint)
      return success(existing) if existing

      findings = evaluate_with_llm
      return success(nil) if findings.nil?

      assessment = nil
      ActiveRecord::Base.transaction do
        @adr.quality_assessments.llm_layer.close_previous_findings!(findings)
        assessment = @adr.quality_assessments.create!(
          layer: "llm",
          content_fingerprint: fingerprint,
          findings: findings,
          reviewed_at: findings.empty? ? Time.current : nil,
          origin: @origin
        )
      end
      success(assessment)
    end

    private

    # 失敗時は nil を返して縮退する（評価は記録しない）
    def evaluate_with_llm
      # モデルは RubyLLM のモデルレジストリに存在しないため、
      # provider 指定 + assume_model_exists でレジストリ解決を迂回する
      llm = llm_context.chat(
        model: AdrManagement.model_for(:quality_assessment),
        provider: :openai, assume_model_exists: true
      )
      parse_findings(llm.ask(prompt).content)
    rescue StandardError => e
      Rails.error.report(e, context: { adr_id: @adr.id }, source: "adr_management.quality")
      nil
    end

    # バックグラウンド実行のためユーザー対面の応答時間制約はないが、
    # ジョブワーカーの長時間占有を避けるため専用のタイムアウトを設定する
    def llm_context
      RubyLLM.context { |config| config.request_timeout = REQUEST_TIMEOUT }
    end

    def prompt
      <<~PROMPT
        あなたは ADR（アーキテクチャ決定記録）の品質評価者です。以下の ADR を3つの観点で評価し、
        問題がある観点のみを所見として JSON で出力してください。所見は登録者への参考情報です。

        観点（code はこの3つのみ使用）:
        1. ai_error_example_weak — この ADR を知らない AI エージェントが誤った実装・提案をする
           具体的な場面を1つ挙げられるか。挙げられないなら、この記録の資産価値は低い
        2. reevaluation_condition_unobservable — 再評価条件（あれば）は「何を見れば発火が分かるか」
           （判定者・観測データ）を特定できるか。再評価条件がない場合はこの観点を出力しない
        3. generic_knowledge — 決定内容が一般的なベストプラクティスの再掲に終始していないか。
           プロジェクト固有の制約・実測値・失敗経緯のいずれかを含むか

        出力は次の JSON のみ（問題がなければ findings は空配列）:
        {"findings": [{"code": "...", "field": "対象フィールド名", "message": "指摘と是正方法（200字以内）"}]}

        # 対象 ADR
        タイトル: #{@adr.title}

        ## コンテキスト
        #{@adr.context}

        ## 決定
        #{@adr.decision}

        ## 結果
        #{@adr.consequences}

        ## 代替案
        #{@adr.alternatives.presence || "（記載なし）"}

        ## 再評価条件
        #{@adr.reevaluation_conditions.presence || "（記載なし）"}
      PROMPT
    end

    def parse_findings(content)
      json = content.to_s[/\{.*\}/m]
      raise ArgumentError, "LLM 応答に JSON が含まれていません" unless json

      Array(JSON.parse(json)["findings"]).filter_map do |finding|
        next unless finding.is_a?(Hash)
        next unless FINDING_CODES.include?(finding["code"]) && finding["message"].present?

        {
          "code" => finding["code"],
          "field" => finding["field"].to_s,
          "message" => finding["message"].to_s.truncate(400)
        }
      end.first(MAX_FINDINGS)
    end
  end
end
