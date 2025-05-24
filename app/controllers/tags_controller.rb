class TagsController < ApplicationController
  def show
    @tag = Tag.find_by!(slug: params[:slug])
    @articles = Article.published.tagged_with(params[:slug]).includes(:tags)

    # SEO用の情報を準備
    @page_title = @tag.page_title
    @page_description = @tag.description
    @canonical_url = tag_articles_url(@tag.slug)
  rescue ActiveRecord::RecordNotFound
    redirect_to articles_path, alert: "タグが見つかりませんでした"
  end
end
