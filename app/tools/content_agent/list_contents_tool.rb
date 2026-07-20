# frozen_string_literal: true

module ContentAgent
  # 掲載内容の一覧・検索（読み取り系）。データベースを変更しないため
  # 承認なしで自動実行してよい。
  class ListContentsTool < RubyLLM::Tool
    description "掲載内容（Project/SpeakingEngagement/UsesItem/Slide）を一覧・検索する。" \
                "keyword を指定するとタイトル・名前・説明の部分一致で絞り込む。"

    param :target_type, desc: "対象種別: Project / SpeakingEngagement / UsesItem / Slide"
    param :keyword, desc: "絞り込みキーワード（部分一致）", required: false
    param :limit, type: "integer", desc: "最大件数（既定20、最大50）", required: false

    def execute(target_type:, keyword: nil, limit: nil)
      return { error: "target_type は #{PendingChange::TARGET_TYPES.join(' / ')} のいずれかを指定してください" } unless PendingChange::TARGET_TYPES.include?(target_type)

      limit = limit.nil? ? 20 : limit.to_i.clamp(1, 50)
      records = scoped_records(target_type, keyword).limit(limit)
      { items: records.map { |record| summarize(target_type, record) } }
    end

    private

    def scoped_records(target_type, keyword)
      case target_type
      when "Project"
        scope = Project.order(published_at: :desc)
        scope = scope.where("title LIKE :kw OR description LIKE :kw", kw: "%#{keyword}%") if keyword.present?
        scope
      when "SpeakingEngagement"
        scope = SpeakingEngagement.ordered.includes(:tags)
        scope = scope.where("title LIKE :kw OR event_name LIKE :kw OR description LIKE :kw", kw: "%#{keyword}%") if keyword.present?
        scope
      when "UsesItem"
        scope = UsesItem.order(:category, :position)
        scope = scope.where("name LIKE :kw OR description LIKE :kw", kw: "%#{keyword}%") if keyword.present?
        scope
      when "Slide"
        scope = Slide.order(published_at: :desc).includes(:tags)
        scope = scope.where("title LIKE :kw OR description LIKE :kw", kw: "%#{keyword}%") if keyword.present?
        scope
      end
    end

    def summarize(target_type, record)
      case target_type
      when "Project"
        { id: record.id, title: record.title, description: record.description.to_s.truncate(120),
          published_at: record.published_at }
      when "SpeakingEngagement"
        { id: record.id, title: record.title, slug: record.slug, event_name: record.event_name,
          event_date: record.event_date, published: record.published, tags: record.tags.map(&:name) }
      when "UsesItem"
        { id: record.id, name: record.name, slug: record.slug, category: record.category,
          published: record.published, discontinued: record.discontinued }
      when "Slide"
        { id: record.id, title: record.title, slug: record.slug,
          published_at: record.published_at, tags: record.tags.map(&:name) }
      end
    end
  end
end
