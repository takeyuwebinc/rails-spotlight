class HomeController < ApplicationController
  def index
    @featured_projects = Project.published.limit(3)

    # Ruby on Rails受託開発に特化したSEOメタデータ
    @seo_title = "Ruby on Rails受託開発"
    @seo_description = "タケユー・ウェブ株式会社は、Ruby on Railsに特化したWeb開発会社です。高品質なWebアプリケーション開発、システム設計、技術コンサルティングを提供しています。Rails開発の外注・委託はお任せください。"
    @seo_og_type = "website"
    @seo_canonical_url = root_url
  end

  # TODO: Add resources for articles
  def about
  end
end
