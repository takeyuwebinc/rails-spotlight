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

    # ADR 間参照の抽出対象となる本文フィールド
    REFERENCE_SOURCE_ATTRIBUTES = %w[
      context decision consequences alternatives reevaluation_conditions
      reference_links
    ].freeze

    # キーワード検索が本文として一致を取るカラム
    KEYWORD_SEARCH_ATTRIBUTES = %w[
      title context decision consequences alternatives
    ].freeze

    # 検索エイリアスの生成元となる本文フィールド。エイリアスはキーワード検索の
    # 一致対象カラムの表記ゆれを補うものであり、生成元は一致対象と同一になる
    ALIAS_SOURCE_ATTRIBUTES = KEYWORD_SEARCH_ATTRIBUTES

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

    has_many :outgoing_references, class_name: "AdrManagement::AdrReference",
      foreign_key: :source_adr_id, inverse_of: :source_adr, dependent: :delete_all
    has_many :incoming_references, class_name: "AdrManagement::AdrReference",
      foreign_key: :target_adr_id, inverse_of: :target_adr, dependent: :delete_all
    has_many :referenced_adrs, through: :outgoing_references, source: :target_adr
    has_many :referencing_adrs, through: :incoming_references, source: :source_adr

    has_many :revisions, class_name: "AdrManagement::AdrRevision",
      dependent: :destroy
    has_many :chunks, class_name: "AdrManagement::AdrChunk",
      dependent: :delete_all
    has_many :golden_queries, class_name: "AdrManagement::GoldenQuery",
      dependent: :destroy
    has_many :reevaluation_checks, class_name: "AdrManagement::ReevaluationCheck",
      dependent: :delete_all
    has_many :quality_assessments, class_name: "AdrManagement::QualityAssessment",
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

    # キーワードの部分一致。本文カラムに加え、登録時に生成した検索エイリアスにも
    # 一致させる。本文が英語表記の用語をカタカナで検索したときの0件を防ぐため
    scope :keyword_match, ->(keyword) {
      pattern = "%#{sanitize_sql_like(keyword)}%"
      columns = KEYWORD_SEARCH_ATTRIBUTES + [ "search_aliases" ]
      where(columns.map { |column| "#{column} LIKE :pattern" }.join(" OR "), pattern: pattern)
    }

    # 効力を失ったステータス。これらへの遷移時、未処理の品質所見は
    # レビューする意味がなくなるため自動クローズする
    RETIRED_STATUSES = %w[superseded rejected deprecated].freeze

    after_update :close_quality_findings_on_retirement

    # ADR 番号の表示名（例: SPOTLIGHT-RAILS-12）。案件 code は照合用に
    # 小文字で保持し、ADR 番号としての表示時のみ大文字にする。
    def display_number
      "#{engagement.code.upcase}-#{number}"
    end

    # URL では DB の id ではなく ADR 番号を用いる（用語集で id の対外露出は禁止）
    def to_param
      display_number
    end

    # 本文テキスト中で ADR 番号表記の候補となるトークン。単語境界で区切った
    # 英数字とハイフンの最大連続列のうち、英字で始まり「-連番」で終わるもの
    DISPLAY_NUMBER_TOKEN = /(?<![A-Za-z0-9-])[A-Za-z][A-Za-z0-9-]*-\d+(?![A-Za-z0-9-])/

    # 表示用 ADR 番号のトークンを [案件 code（小文字）, 連番] に分割する。
    # 案件 code はハイフンを含み得るため、末尾のハイフン以降を連番とする。
    # 形式が不正な場合は nil を返す
    def self.split_display_number(value)
      code, separator, number = value.to_s.rpartition("-")
      return nil unless separator == "-" && code.present? && number.match?(/\A\d+\z/)

      [ code.downcase, Integer(number, 10) ]
    end

    # 表示用 ADR 番号（例: SPOTLIGHT-RAILS-12）から ADR を引く
    def self.find_by_display_number!(value)
      code_and_number = split_display_number(value)
      raise ActiveRecord::RecordNotFound, "ADR 番号の形式が不正です: #{value}" unless code_and_number

      code, number = code_and_number
      engagement = Engagement.where("LOWER(code) = ?", code).first
      raise ActiveRecord::RecordNotFound, "案件（code: #{code}）が存在しません" unless engagement

      engagement.adrs.find_by!(number: number)
    end

    # テキスト中の ADR 番号表記を解決する。トークン全体が「実在する案件 code
    # ＋実在する連番」に一致する場合のみ解決し（大文字小文字非依存）、
    # トークン内部の部分一致は行わない。戻り値:
    #   references: 解決できた表記（トークン文字列 => Adr）
    #   unknown_numbers: 案件 code は実在するが連番が存在しない表記の配列
    # 案件 code 自体が実在しない表記（UTF-8 等の一般表記）はどちらにも含めない
    def self.resolve_text_references(*texts)
      tokens = texts.compact.flat_map { |text| text.scan(DISPLAY_NUMBER_TOKEN) }.uniq
      candidates = tokens.filter_map do |token|
        code, number = split_display_number(token)
        code && { token: token, code: code, number: number }
      end
      return { references: {}, unknown_numbers: [] } if candidates.empty?

      engagements = Engagement.where("LOWER(code) IN (?)", candidates.map { |c| c[:code] }.uniq)
        .index_by { |engagement| engagement.code.downcase }
      adr_scope = candidates.filter_map do |candidate|
        engagement = engagements[candidate[:code]]
        engagement && Adr.where(engagement_id: engagement.id, number: candidate[:number])
      end.reduce(:or)
      adrs = adr_scope ? adr_scope.to_a : []

      references = {}
      unknown_numbers = []
      candidates.each do |candidate|
        engagement = engagements[candidate[:code]]
        next unless engagement

        adr = adrs.find { |a| a.engagement_id == engagement.id && a.number == candidate[:number] }
        if adr
          references[candidate[:token]] = adr
        else
          unknown_numbers << candidate[:token]
        end
      end
      { references: references, unknown_numbers: unknown_numbers }
    end

    # 本文（検索エイリアスを除く）に検索語を含むか。エイリアスでのみ一致した
    # 結果は利用者が本文から検索語を確認できないため、区別して扱う
    def body_matches_keyword?(keyword)
      needle = keyword.to_s.downcase
      KEYWORD_SEARCH_ATTRIBUTES.any? do |attribute|
        public_send(attribute).to_s.downcase.include?(needle)
      end
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

    def close_quality_findings_on_retirement
      return unless saved_change_to_status? && RETIRED_STATUSES.include?(status)

      quality_assessments.pending_review.find_each do |assessment|
        assessment.close_open_findings!(result: "obsolete")
      end
    end

    def project_belongs_to_same_engagement
      return if project.nil? || project.engagement_id == engagement_id

      errors.add(:project, :invalid)
    end
  end
end
