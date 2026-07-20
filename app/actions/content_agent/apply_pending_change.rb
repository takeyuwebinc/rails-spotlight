# frozen_string_literal: true

module ContentAgent
  # 承認された保留変更を掲載内容へ反映する唯一の入口。
  # プレビュー（保留変更の内容）と反映内容の同一性を保証するため、
  # 保留変更の payload をそのまま適用し、途中で内容を書き換えない。
  # 適用は保留変更の状態更新と同一トランザクションで行い、失敗時は
  # 掲載内容を変更せずエラー内容を保留変更へ記録する。
  class ApplyPendingChange < ApplicationAction
    class ApplyError < StandardError; end

    # payload から掲載レコードへ渡してよい属性。管理外の属性
    # （id・タイムスタンプ等）が LLM 由来の payload に紛れても無視する。
    ALLOWED_ATTRIBUTES = {
      "Project" => %w[title description icon color technologies published_at position],
      "SpeakingEngagement" => %w[title slug event_name event_date event_url location
                                 description slides_url position published],
      "UsesItem" => %w[name slug category description url discontinued position published],
      "Slide" => %w[title slug description published_at]
    }.freeze

    def initialize(pending_change:)
      @pending_change = pending_change
    end

    def perform
      return failure("承認待ちの保留変更ではありません（現在: #{@pending_change.status}）") unless @pending_change.pending?

      record = nil
      ActiveRecord::Base.transaction do
        record = apply_to_target!
        @pending_change.mark_applied!
      end
      success(record)
    rescue ActiveRecord::RecordInvalid => e
      register_failure(e.record.errors.full_messages.join(", "))
    rescue ApplyError => e
      register_failure(e.message)
    end

    private

    def register_failure(message)
      @pending_change.mark_apply_failed!(message)
      failure(message)
    end

    def apply_to_target!
      return apply_slide_markdown! if slide_markdown_operation?

      case @pending_change.operation
      when "create" then create_record!
      when "update" then update_record!
      when "toggle_publication" then toggle_publication!
      end
    end

    def slide_markdown_operation?
      @pending_change.target_type == "Slide" &&
        !@pending_change.operation_toggle_publication? &&
        @pending_change.payload.key?("content")
    end

    def apply_slide_markdown!
      slide = Slide.import_from_markdown(@pending_change.payload["content"])
      raise ApplyError, "Slide の markdown 取り込みに失敗しました。frontmatter（title, slug, description, published_date, category: slide）を確認してください" if slide.nil?

      slide
    end

    def create_record!
      record = model_class.new(permitted_attributes)
      record.save!
      assign_tags!(record)
      record
    end

    def update_record!
      record = find_target!
      record.update!(permitted_attributes)
      assign_tags!(record)
      record
    end

    def toggle_publication!
      record = find_target!
      record.update!(permitted_publication_attributes)
      record
    end

    def find_target!
      @pending_change.target_record ||
        raise(ApplyError, "対象レコードが見つかりません（#{@pending_change.target_type} ##{@pending_change.target_id}）")
    end

    def model_class
      @pending_change.target_type.constantize
    end

    def permitted_attributes
      @pending_change.payload.slice(*ALLOWED_ATTRIBUTES.fetch(@pending_change.target_type))
    end

    def permitted_publication_attributes
      attrs = @pending_change.payload.slice("published", "published_at")
      raise ApplyError, "公開状態（published または published_at）を指定してください" if attrs.blank?

      attrs
    end

    def assign_tags!(record)
      tag_names = @pending_change.payload["tags"]
      return if tag_names.nil? || !record.respond_to?(:tags)

      record.tags = Array(tag_names).map { |name| Tag.find_or_create_by!(name: name) }
    end
  end
end
