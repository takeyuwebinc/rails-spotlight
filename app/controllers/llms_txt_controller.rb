class LlmsTxtController < ApplicationController
  # キャッシュヘッダーの設定
  before_action :set_cache_headers

  def show
    @data = gather_site_data

    respond_to do |format|
      format.text { render plain: generate_llms_txt }
      format.any { render plain: generate_llms_txt, content_type: "text/plain" }
    end
  end

  private

  def gather_site_data
    {
      projects_count: Project.published.count,
      speaking_count: SpeakingEngagement.published.count,
      uses_count: UsesItem.count,
      availability: calculate_availability,
      generated_at: Time.current
    }
  end

  def calculate_availability
    # TODO: 実際の稼働状況を計算するロジックを実装
    {
      current_capacity: 95,
      next_available: "3ヶ月後",
      status: "相談可"
    }
  end

  def generate_llms_txt
    render_to_string(
      template: "llms_txt/show",
      formats: [ :text ],
      layout: false,
      locals: { data: @data }
    )
  end

  def set_cache_headers
    expires_in 1.hour, public: true

    # 条件付きGETのサポート
    last_modified = calculate_last_modified
    etag_value = calculate_etag

    fresh_when(last_modified: last_modified, etag: etag_value)
  end

  def calculate_last_modified
    [
      Project.published.maximum(:updated_at),
      SpeakingEngagement.published.maximum(:updated_at),
      UsesItem.maximum(:updated_at)
    ].compact.max || Time.current
  end

  def calculate_etag
    Digest::MD5.hexdigest([
      Project.published.count,
      SpeakingEngagement.published.count,
      UsesItem.count,
      Rails.application.config.cache_classes
    ].join("-"))
  end
end
