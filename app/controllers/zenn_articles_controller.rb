# Zenn記事のTurbo Frame用コントローラー
#
# トップページの記事セクションを非同期で読み込むためのエンドポイント
class ZennArticlesController < ApplicationController
  def index
    @articles = ZennArticle.all(limit: 3)
  end
end
