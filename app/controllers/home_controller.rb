class HomeController < ApplicationController
  def index
    @articles = Article.published.limit(3)
    @featured_projects = Project.ordered.limit(5)
  end

  # TODO: Add resources for articles, projects, speaking, and uses
  def about
  end

  def projects
    @projects = Project.ordered
  end

  def speaking
  end

  def uses
  end
end
