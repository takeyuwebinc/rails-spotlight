class ArticlesController < ApplicationController
  def index
    @articles = Article.published
  end

  def show
    @article = Article.find_by!(slug: params[:slug])
  rescue ActiveRecord::RecordNotFound
    redirect_to articles_path, alert: "記事が見つかりませんでした"
  end
end
