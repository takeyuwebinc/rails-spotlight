# frozen_string_literal: true

module Observability
  # before_send_log フックとして登録し、本文がパターンに一致するログを
  # 送信前に破棄する（nil を返すと SDK が破棄する）。
  #
  # SolidQueue・SolidCable などフレームワーク内部の動作は、トレース
  # （SpanDropExporter で除外）だけでなくログにも大量に現れる：
  # - ActiveJob のジョブ実行ログ（Performed SolidCable::TrimJob ... 等）
  # - structured_logging の DB クエリログ（Database query: SolidCable::Message Insert 等）
  # - SolidQueue スーパーバイザ自身のログ
  # いずれも本文にコンポーネント名を含むため、本文の一致で判定する。
  class LogDropFilter
    def initialize(pattern)
      @pattern = pattern
    end

    def call(log)
      log.body&.match?(@pattern) ? nil : log
    end
  end
end
