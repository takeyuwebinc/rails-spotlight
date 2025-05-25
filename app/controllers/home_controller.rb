class HomeController < ApplicationController
  def index
    @articles = Article.published.includes(:tags).limit(3)
    @featured_projects = Project.published.limit(5)
    @featured_tags = Tag.joins(:articles)
                        .where("articles.published_at <= ?", Time.current)
                        .group("tags.id")
                        .order("COUNT(articles.id) DESC")
                        .limit(5)
  end

  # TODO: Add resources for articles and speaking
  def about
  end

  def speaking
  end
end
