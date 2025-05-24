module ApplicationHelper
  def home?
    params[:controller] == "home" && params[:action] == "index"
  end

  # ページタイトルを生成する
  # @param title [String] ページ固有のタイトル
  # @return [String] 完全なページタイトル
  def page_title(title = nil)
    base_title = "TakeyuWeb"
    title.present? ? "#{title} | #{base_title}" : base_title
  end

  # ページ説明文を生成する
  # @param description [String] ページ固有の説明文
  # @return [String] ページの説明文
  def page_description(description = nil)
    description.presence || "技術ブログ - Rails、JavaScript、Web開発に関する記事を発信しています"
  end

  # canonical URLを生成する
  # @param url [String] canonical URL（省略時は現在のURL）
  # @return [String] canonical URL
  def canonical_url(url = nil)
    url || request.original_url
  end

  # Open Graph用の画像URLを生成する
  # @param image_path [String] 画像パス
  # @return [String] 完全なURL
  def og_image_url(image_path = nil)
    default_image = asset_url("logo.png")
    image_path ? asset_url(image_path) : default_image
  end
end
