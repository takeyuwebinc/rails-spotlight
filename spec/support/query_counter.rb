# frozen_string_literal: true

# ブロック内で発行された SQL クエリ数を数える。N+1 が起きていないことの検証に使う。
# SCHEMA / TRANSACTION などの内部クエリはアプリケーションの意図した問い合わせではないため除外する。
module QueryCounter
  IGNORED_NAMES = %w[SCHEMA TRANSACTION CACHE].freeze

  def count_queries(&block)
    count = 0
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      count += 1 unless IGNORED_NAMES.include?(payload[:name]) || payload[:sql].match?(/\A\s*(BEGIN|COMMIT|ROLLBACK|RELEASE|SAVEPOINT)/i)
    end
    block.call
    count
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end

RSpec.configure do |config|
  config.include QueryCounter
end
