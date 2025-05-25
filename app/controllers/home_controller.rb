class HomeController < ApplicationController
  def index
    @articles = Article.published.includes(:tags).limit(3)
    @featured_projects = Project.published.limit(5)
    @featured_tags = Tag.joins(:articles)
                        .where("articles.published_at <= ?", Time.current)
                        .group("tags.id")
                        .having("COUNT(articles.id) >= ?", 3)
                        .order("COUNT(articles.id) DESC")
                        .limit(5)
  end

  # TODO: Add resources for articles
  def about
  end
end
