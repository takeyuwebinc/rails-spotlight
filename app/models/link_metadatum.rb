# URLメタデータのキャッシュを管理するモデル
#
# このモデルは、URLのメタデータ（タイトル、説明、ドメイン、ファビコン、画像URL）を
# キャッシュするために使用されます。キャッシュは一定期間（デフォルトで24時間）有効です。
class LinkMetadatum < ApplicationRecord
  validates :url, presence: true, uniqueness: true
  validates :last_fetched_at, presence: true

  # URLからメタデータを取得する
  #
  # @param url [String] メタデータを取得するURL
  # @return [Hash] メタデータのハッシュ（タイトル、説明、ドメイン、ファビコン、画像URL）
  #   または、エラーが発生した場合はエラー情報を含むハッシュ
  # @example
  #   LinkMetadatum.fetch_metadata('https://example.com')
  #   # => { title: 'Example Domain', description: '...', domain: 'example.com', ... }
  def self.fetch_metadata(url)
    return { error: "URL parameter is required" } unless url.present?

    # キャッシュを確認
    cached_metadata = find_by(url: url)

    # キャッシュが有効な場合
    if cached_metadata && cached_metadata.cache_valid?
      return {
        title: cached_metadata.title,
        description: cached_metadata.description,
        domain: cached_metadata.domain,
        favicon: cached_metadata.favicon,
        imageUrl: cached_metadata.image_url
      }
    end

    # キャッシュがない場合または無効な場合は新しく取得
    begin
      # MetaInspectorを使用してURLからメタデータを取得
      page = MetaInspector.new(url, timeout: 5)

      # レスポンスデータを構築
      data = {
        title: page.title.to_s.strip,
        description: page.best_description.to_s.strip,
        domain: page.host,
        favicon: page.images.favicon.to_s,
        imageUrl: page.images.best.to_s
      }

      # キャッシュを更新または作成
      if cached_metadata
        cached_metadata.update_cache(data)
      else
        create(
          url: url,
          title: data[:title],
          description: data[:description],
          domain: data[:domain],
          favicon: data[:favicon],
          image_url: data[:imageUrl],
          last_fetched_at: Time.current
        )
      end

      data
    rescue MetaInspector::TimeoutError, MetaInspector::RequestError,
           MetaInspector::ParserError, MetaInspector::NonHtmlError => e
      # 想定内のエラー（タイムアウト、リクエストエラー、パースエラー、非HTMLエラー）
      # これらはユーザーに直接表示しても問題ない
      { error: e.message }
    rescue => e
      # 想定外のエラー
      # Railsのエラーレポート機能を使用して報告
      Rails.error.report(e, context: { url: url })
      # ユーザーには一般的なエラーメッセージを返す
      { error: "メタデータの取得中に問題が発生しました。しばらく経ってからもう一度お試しください。" }
    end
  end

  # キャッシュが有効かどうかを確認する
  #
  # @return [Boolean] キャッシュが有効な場合はtrue、そうでない場合はfalse
  # @example
  #   metadata = LinkMetadatum.find_by(url: 'https://example.com')
  #   metadata.cache_valid? # => true/false
  def cache_valid?
    last_fetched_at > self.class.cache_duration.ago
  end

  # キャッシュを更新する
  #
  # @param metadata [Hash] 更新するメタデータのハッシュ
  # @option metadata [String] :title タイトル
  # @option metadata [String] :description 説明
  # @option metadata [String] :domain ドメイン
  # @option metadata [String] :favicon ファビコンURL
  # @option metadata [String] :imageUrl 画像URL
  # @return [Boolean] 更新が成功した場合はtrue、そうでない場合はfalse
  # @example
  #   metadata = LinkMetadatum.find_by(url: 'https://example.com')
  #   metadata.update_cache({
  #     title: 'New Title',
  #     description: 'New Description',
  #     domain: 'example.com',
  #     favicon: 'https://example.com/favicon.ico',
  #     imageUrl: 'https://example.com/image.jpg'
  #   })
  def update_cache(metadata)
    update(
      title: metadata[:title],
      description: metadata[:description],
      domain: metadata[:domain],
      favicon: metadata[:favicon],
      image_url: metadata[:imageUrl],
      last_fetched_at: Time.current
    )
  end

  # キャッシュ期間を取得する
  #
  # @return [ActiveSupport::Duration] キャッシュ期間（デフォルトは24時間）
  # @example
  #   LinkMetadatum.cache_duration # => 24.hours
  def self.cache_duration
    Rails.application.config.respond_to?(:link_metadata_cache_duration) ?
      Rails.application.config.link_metadata_cache_duration :
      24.hours
  end
end
