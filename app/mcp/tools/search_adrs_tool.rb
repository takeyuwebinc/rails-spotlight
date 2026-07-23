# frozen_string_literal: true

module Tools
  class SearchAdrsTool < MCP::Tool
    extend AdrManagementToolSupport

    DEFAULT_LIMIT = 10
    MAX_LIMIT = 30

    description "Search ADRs (architecture decision records). " \
                "Natural language search (query) and keyword/attribute search (keyword and filters) are available. " \
                "Omit engagement_code to search across all engagements. " \
                "Returns summaries; use get_adr_tool to read the full text. " \
                "Embedding-based search is weak against paraphrasing: run multiple phrasings and " \
                "combine with keyword search before concluding nothing is relevant. " \
                "For periodic reevaluation review, use unchecked_for_days / check_result WITHOUT query " \
                "(combine with status: accepted): the natural language path truncates to the top-scored " \
                "results before filtering and is not exhaustive. " \
                "If a search misses an ADR you later reach via another route (keyword search, listing, " \
                "prior knowledge), report it with report_search_miss_tool."

    input_schema(
      properties: {
        query: {
          type: "string",
          description: "Natural language question (e.g. 認証まわりで過去に決めたことは？). Relevance scores are returned. Attribute filters are applied after scoring."
        },
        keyword: {
          type: "string",
          description: "Keyword for partial match against title and body fields (used when query is not given)"
        },
        engagement_code: {
          type: "string",
          description: "Restrict the search to this engagement. Omit for cross-engagement search"
        },
        project_name: {
          type: "string",
          description: "Filter by project name (exact match)"
        },
        status: {
          type: "string",
          enum: AdrManagement::Adr::STATUSES,
          description: "Filter by status"
        },
        confidence: {
          type: "string",
          enum: AdrManagement::Adr::CONFIDENCES,
          description: "Filter by confidence"
        },
        decided_after: {
          type: "string",
          description: "Filter: decided on or after this date (YYYY-MM-DD)"
        },
        decided_before: {
          type: "string",
          description: "Filter: decided on or before this date (YYYY-MM-DD)"
        },
        unchecked_for_days: {
          type: "integer",
          description: "Filter: ADRs with reevaluation conditions and no reevaluation check " \
                       "newer than N days (includes never-checked ADRs; a check exactly N days " \
                       "ago counts as due). Must be 1 or greater"
        },
        check_result: {
          type: "string",
          enum: AdrManagement::ReevaluationCheck::RESULTS,
          description: "Filter: ADRs whose latest reevaluation check has this result " \
                       "(use suspected to collect pending trigger observations)"
        },
        limit: {
          type: "integer",
          description: "Maximum number of results (default #{DEFAULT_LIMIT}, max #{MAX_LIMIT})"
        }
      },
      required: []
    )

    def self.call(query: nil, keyword: nil, engagement_code: nil, project_name: nil,
                  status: nil, confidence: nil, decided_after: nil, decided_before: nil,
                  unchecked_for_days: nil, check_result: nil, limit: nil, server_context:)
      engagement = nil
      if engagement_code.present?
        engagement = find_engagement_or_error(engagement_code)
        return engagement if engagement.is_a?(MCP::Tool::Response)
      end

      after_date, error = parse_date_or_error(decided_after, "decided_after")
      return error if error
      before_date, error = parse_date_or_error(decided_before, "decided_before")
      return error if error

      if unchecked_for_days && unchecked_for_days < 1
        return error_response(AdrManagement::OperationError.build(
          kind: :invalid_input,
          param: "unchecked_for_days",
          message: "unchecked_for_days には1以上の日数を指定してください: #{unchecked_for_days}",
          next_action: "点検期限の日数（例: 30）を指定してください"
        ))
      end

      limit = (limit || DEFAULT_LIMIT).clamp(1, MAX_LIMIT)
      filters = { engagement: engagement, project_name: project_name, status: status,
                  confidence: confidence, after: after_date, before: before_date,
                  unchecked_for_days: unchecked_for_days, check_result: check_result }

      origin = origin_from(server_context)
      if query.present?
        natural_language_search(query, filters, limit, origin)
      else
        keyword_search(keyword, filters, limit, origin)
      end
    rescue => e
      text_response("Error searching ADRs: #{e.message}")
    end

    def self.natural_language_search(query, filters, limit, origin)
      result = AdrManagement::SearchNaturalLanguage.perform(
        query: query, engagement: filters[:engagement], limit: limit
      )
      return error_response(result.errors) if result.failure?

      scored = result.data.select { |entry| matches_filters?(entry.adr, filters) }
      record_search_log(
        mode: "natural_language", query: query, filters: filters, origin: origin,
        results: scored.map { |entry| { adr_id: entry.adr.id, score: entry.score.round(4) } },
        result_count: scored.size
      )
      return empty_result_response(cross_engagement: filters[:engagement].nil?) if scored.empty?

      list = scored.map { |entry| adr_summary_line(entry.adr, relevance: entry.score) }.join("\n")
      text_response(
        "Found #{scored.size} ADR(s) (natural language search):\n#{list}\n\n" \
        "全文は get_adr_tool（engagement_code と number を指定）で参照できます。"
      )
    end

    def self.keyword_search(keyword, filters, limit, origin)
      adrs = AdrManagement::Adr.includes(:engagement)
      adrs = adrs.where(engagement: filters[:engagement]) if filters[:engagement]
      adrs = apply_attribute_filters(adrs, filters)

      if keyword.present?
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(keyword)}%"
        adrs = adrs.where(
          [ "title", "context", "decision", "consequences", "alternatives" ]
            .map { |column| "#{column} LIKE :pattern" }.join(" OR "),
          pattern: pattern
        )
      end

      total = adrs.count
      adrs = adrs.order(decided_on: :desc, id: :desc).limit(limit)
      record_search_log(
        mode: "keyword", keyword: keyword, filters: filters, origin: origin,
        results: adrs.map { |adr| { adr_id: adr.id } },
        result_count: total
      )
      return empty_result_response(cross_engagement: filters[:engagement].nil?) if total.zero?

      list = adrs.map { |adr| adr_summary_line(adr) }.join("\n")
      note = total > limit ? "\n（他 #{total - limit} 件。日付・ステータス等で絞り込んでください）" : ""
      text_response(
        "Found #{total} ADR(s) (keyword/attribute search, newest first):\n#{list}#{note}\n\n" \
        "全文は get_adr_tool（engagement_code と number を指定）で参照できます。"
      )
    end

    def self.apply_attribute_filters(adrs, filters)
      adrs = adrs.where(status: filters[:status]) if filters[:status].present?
      adrs = adrs.where(confidence: filters[:confidence]) if filters[:confidence].present?
      adrs = adrs.where(decided_on: filters[:after]..) if filters[:after]
      adrs = adrs.where(decided_on: ..filters[:before]) if filters[:before]
      if filters[:project_name].present?
        adrs = adrs.joins(:project).where(adr_management_projects: { name: filters[:project_name] })
      end
      if filters[:unchecked_for_days]
        # 条件を持たない ADR は点検登録が不可のため対象外にする。含めると
        # 永久に「未点検」でマッチし続け、点検による差分消化が収束しない
        adrs = adrs.where.not(reevaluation_conditions: [ nil, "" ])
          .where.not(id: AdrManagement::ReevaluationCheck.adr_ids_checked_within(filters[:unchecked_for_days]))
      end
      if filters[:check_result].present?
        adrs = adrs.where(id: AdrManagement::ReevaluationCheck.adr_ids_with_latest_result(filters[:check_result]))
      end
      adrs
    end

    def self.matches_filters?(adr, filters)
      return false if filters[:status].present? && adr.status != filters[:status]
      return false if filters[:confidence].present? && adr.confidence != filters[:confidence]
      return false if filters[:after] && adr.decided_on < filters[:after]
      return false if filters[:before] && adr.decided_on > filters[:before]
      return false if filters[:project_name].present? && adr.project&.name != filters[:project_name]
      return false unless matches_check_filters?(adr, filters)

      true
    end

    def self.matches_check_filters?(adr, filters)
      if filters[:unchecked_for_days]
        return false if adr.reevaluation_conditions.blank?

        cutoff = Date.current - filters[:unchecked_for_days]
        return false if adr.reevaluation_checks.any? { |check| check.checked_on > cutoff }
      end

      if filters[:check_result].present?
        latest = adr.reevaluation_checks.max_by { |check| [ check.checked_on, check.id ] }
        return false unless latest&.result == filters[:check_result]
      end

      true
    end

    # 0件はエラーではなく空一覧として返す。Agent が「関連 ADR なし」と
    # 早合点して確認手順を飛ばさないよう、再検索のガイダンスを添える。
    def self.empty_result_response(cross_engagement:)
      guidance = [
        "該当する ADR は見つかりませんでした（0件）。関連 ADR が存在しないと結論づける前に:",
        "- 別の言い回しで再検索する（埋め込み検索は言い換えに弱いため）",
        "- keyword によるキーワード検索に切り替える",
        "- 絞り込み条件（status・confidence・日付）を外す"
      ]
      guidance << "- engagement_code を外して案件横断で検索する" unless cross_engagement
      guidance << "- 別経路（キーワード検索・一覧・既知の番号）で目的の ADR に後から到達した場合は、" \
                  "report_search_miss_tool で取り逃がしを報告する"
      text_response(guidance.join("\n"))
    end

    # 検索ログの記録失敗で検索本体を失敗させない（索引更新と同じ
    # ベストエフォート方針。ログは分析用であり検索の契約に含めない）
    def self.record_search_log(mode:, filters:, origin:, results:, result_count:, query: nil, keyword: nil)
      AdrManagement::SearchLog.create!(
        mode: mode, query: query, keyword: keyword,
        engagement: filters[:engagement],
        filters: loggable_filters(filters),
        results: results, result_count: result_count, origin: origin
      )
    rescue => e
      Rails.error.report(e, handled: true)
    end

    def self.loggable_filters(filters)
      filters.except(:engagement).compact.transform_values(&:to_s)
    end
  end
end
