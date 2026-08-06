# frozen_string_literal: true

module Observability
  # スパン名のプレフィックスに一致するスパンをエクスポートから除外する
  # エクスポータの委譲ラッパー。
  #
  # SolidQueue・SolidCable などフレームワーク内部の DB アクセスは
  # ActiveRecord 計装によりモデル名のスパン（例: SolidQueue::ReadyExecution.create）
  # として大量に生成され、アプリの動作把握には不要なため送信前に落とす。
  # ジョブ自体のスパン（ActiveJob 計装によるキュー名の publish / process）は
  # プレフィックスに一致しないため残る。
  #
  # 除外対象のスパンは子を持たない（ActiveRecord 計装のスパンは末端）ため、
  # 除外によって残したスパンの親が欠けることはない。
  class SpanDropExporter
    def initialize(exporter, name_prefixes:)
      @exporter = exporter
      @name_prefixes = name_prefixes
    end

    def export(span_datas, timeout: nil)
      kept = span_datas.reject { |span_data| drop?(span_data) }
      return OpenTelemetry::SDK::Trace::Export::SUCCESS if kept.empty?

      @exporter.export(kept, timeout: timeout)
    end

    def force_flush(timeout: nil)
      @exporter.force_flush(timeout: timeout)
    end

    def shutdown(timeout: nil)
      @exporter.shutdown(timeout: timeout)
    end

    private

    def drop?(span_data)
      @name_prefixes.any? { |prefix| span_data.name&.start_with?(prefix) }
    end
  end
end
