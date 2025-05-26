module ApplicationHelper
  def home?
    params[:controller] == "home" && params[:action] == "index"
  end

  # ページタイトルを生成する
  # @param title [String] ページ固有のタイトル
  # @return [String] 完全なページタイトル
  def page_title(title = nil)
    base_title = "タケユー・ウェブ株式会社"
    title.present? ? "#{title} | #{base_title}" : "Ruby on Rails受託開発 | #{base_title}"
  end

  # ページ説明文を生成する
  # @param description [String] ページ固有の説明文
  # @return [String] ページの説明文
  def page_description(description = nil)
    description.presence || "タケユー・ウェブ株式会社は、Ruby on Railsに特化したWeb開発会社です。高品質なWebアプリケーション開発、システム設計、技術コンサルティングを提供しています。"
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
