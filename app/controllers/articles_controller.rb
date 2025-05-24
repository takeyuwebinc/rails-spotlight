class ArticlesController < ApplicationController
  def index
    @articles = Article.published
  end

  def show
    @article = Article.includes(:tags).find_by!(slug: params[:slug])
  end
end
