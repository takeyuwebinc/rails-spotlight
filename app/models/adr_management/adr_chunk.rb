# frozen_string_literal: true

module AdrManagement
  # 自然言語検索のための索引データ。ADR 本文を項目単位で分割したチャンクと
  # その埋め込みベクトルを保持する。埋め込みモデルの入力上限（512 トークン、
  # 日本語で約 760 文字）に収まるよう、長い項目はさらに文字数で分割する。
  #
  # state は索引の鮮度。埋め込み API の呼び出しに失敗したチャンクは
  # stale（未更新）のまま残し、次回の検索実行時または再構築で再試行する。
  # 索引が古くても DB を参照するキーワード・属性検索と全文参照の正しさには
  # 影響しない（索引は自然言語検索専用）。
  class AdrChunk < ApplicationRecord
    STATES = %w[fresh stale].freeze

    # 入力上限 512 トークン（日本語で約 760 文字）に対する安全側の分割幅
    MAX_CONTENT_CHARS = 600

    CHUNK_SOURCES = {
      "context" => ->(adr) { adr.context },
      "decision" => ->(adr) { adr.decision },
      "consequences" => ->(adr) { adr.consequences },
      "alternatives" => ->(adr) { adr.alternatives },
      "reevaluation_conditions" => ->(adr) { adr.reevaluation_conditions }
    }.freeze

    belongs_to :adr, class_name: "AdrManagement::Adr"

    validates :kind, presence: true
    validates :content, presence: true
    validates :state, presence: true, inclusion: { in: STATES }

    scope :fresh, -> { where(state: "fresh") }
    scope :stale, -> { where(state: "stale") }

    # ADR 本文から埋め込み対象のチャンク（kind と content の組）を組み立てる。
    # 各チャンクにタイトルを前置し、チャンク単独でどの決定の断片かが
    # 埋め込み空間上で判別できるようにする。
    def self.build_contents_for(adr)
      CHUNK_SOURCES.flat_map do |kind, extractor|
        text = extractor.call(adr)
        next [] if text.blank?

        parts = text.scan(/.{1,#{MAX_CONTENT_CHARS}}/m)
        parts.each_with_index.map do |part, index|
          {
            kind: parts.size > 1 ? "#{kind}:#{index + 1}" : kind,
            content: "#{adr.title}\n\n#{part}"
          }
        end
      end
    end

    def vector
      embedding&.unpack("f*")
    end

    def vector=(values)
      self.embedding = values&.pack("f*")
    end

    def mark_fresh!(values)
      update!(embedding: values.pack("f*"), state: "fresh")
    end

    def similarity_to(query_vector)
      own = vector
      return nil if own.nil? || own.size != query_vector.size

      dot = 0.0
      norm_own = 0.0
      norm_query = 0.0
      own.each_with_index do |value, index|
        dot += value * query_vector[index]
        norm_own += value * value
        norm_query += query_vector[index]**2
      end
      return nil if norm_own.zero? || norm_query.zero?

      dot / (Math.sqrt(norm_own) * Math.sqrt(norm_query))
    end
  end
end
