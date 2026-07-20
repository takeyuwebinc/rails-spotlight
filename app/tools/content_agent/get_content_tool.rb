# frozen_string_literal: true

module ContentAgent
  # 掲載内容 1 件の全属性参照（読み取り系）。更新提案の前に現在値を
  # 確認する用途を想定する。
  class GetContentTool < RubyLLM::Tool
    description "掲載内容 1 件の全属性を取得する。更新・公開切替の提案前に現在値の確認に使う。"

    param :target_type, desc: "対象種別: Project / SpeakingEngagement / UsesItem / Slide"
    param :id, type: "integer", desc: "対象レコードのID"

    def execute(target_type:, id:)
      return { error: "target_type は #{PendingChange::TARGET_TYPES.join(' / ')} のいずれかを指定してください" } unless PendingChange::TARGET_TYPES.include?(target_type)

      record = target_type.constantize.find_by(id: id)
      return { error: "#{target_type} ##{id} は見つかりません" } if record.nil?

      attributes = record.attributes
      attributes["tags"] = record.tags.map(&:name) if record.respond_to?(:tags)
      attributes["page_count"] = record.slide_pages.size if record.is_a?(Slide)
      attributes
    end
  end
end
