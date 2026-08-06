# frozen_string_literal: true

module Observability
  # OTLP エクスポートの直前に、LLM スパンの入出力・ツール引数・ツール結果へ
  # Rails の filter_parameters（キーベースのマスキング）を適用するエクスポータ。
  # スパンは終了後に属性を書き換えられないため、SpanProcessor ではなく
  # エクスポータの委譲ラッパーとして実装している。
  #
  # キーに紐づかない自由文（プロンプト・出力の本文）はキーベースでは
  # マスクできず、そのまま送信されうる。この残余リスクは受容している。
  # 内容の送信自体の可否は環境変数
  # OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT で制御する
  # （計装 gem の既定は送信しない。本アプリは開発・本番とも true を設定している）。
  class GenAiContentFilterExporter
    # 会話・ツール実行の内容が入る属性。値は計装側が生成する JSON 文字列
    # （ツール結果のみ素の文字列のことがある）。
    CONTENT_ATTRIBUTE_KEYS = %w[
      gen_ai.input.messages
      gen_ai.output.messages
      gen_ai.system_instructions
      gen_ai.tool.call.arguments
      gen_ai.tool.call.result
    ].freeze

    # ParameterFilter はハッシュのみ受け取るため、配列やスカラーの
    # トップレベル値を包むための仮キー
    ROOT_KEY = "_root"
    private_constant :ROOT_KEY

    def initialize(exporter, filter_keys: Rails.application.config.filter_parameters)
      @exporter = exporter
      @parameter_filter = ActiveSupport::ParameterFilter.new(filter_keys)
    end

    def export(span_datas, timeout: nil)
      @exporter.export(span_datas.map { |span_data| filtered_span_data(span_data) }, timeout: timeout)
    end

    def force_flush(timeout: nil)
      @exporter.force_flush(timeout: timeout)
    end

    def shutdown(timeout: nil)
      @exporter.shutdown(timeout: timeout)
    end

    private

    def filtered_span_data(span_data)
      attributes = span_data.attributes
      return span_data unless attributes && CONTENT_ATTRIBUTE_KEYS.any? { |key| attributes.key?(key) }

      filtered = attributes.to_h do |key, value|
        [ key, CONTENT_ATTRIBUTE_KEYS.include?(key) ? filter_content(value) : value ]
      end
      span_data.dup.tap { |duped| duped.attributes = filtered }
    end

    # JSON としてパースできる値のみキーベースでマスクする。
    # パース不能な値はキー構造を持たないため対象外としてそのまま通す。
    def filter_content(value)
      parsed = JSON.parse(value)
      JSON.generate(@parameter_filter.filter(ROOT_KEY => parsed)[ROOT_KEY])
    rescue JSON::ParserError, TypeError
      value
    end
  end
end
