class HomeController < ApplicationController
  def index
    @articles = Article.published.limit(3)
  end

  # TODO: Add resources for articles, projects, speaking, and uses
  def about
  end

  def projects
  end

  def speaking
  end

  def uses
  end
end
