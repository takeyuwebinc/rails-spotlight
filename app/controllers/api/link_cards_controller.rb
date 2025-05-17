require 'metainspector'

module Api
  class LinkCardsController < ApplicationController
    def metadata
      url = params[:url]
      
      # URLが提供されていない場合はエラー
      unless url.present?
        return render json: { error: "URL parameter is required" }, status: :bad_request
      end
      
      begin
        # MetaInspectorを使用してURLからメタデータを取得
        page = MetaInspector.new(url, timeout: 5)
        
        # レスポンスデータを構築
        data = {
          title: page.title.to_s.strip,
          description: page.best_description.to_s.strip,
          domain: page.host,
          favicon: page.images.favicon.to_s,
          imageUrl: page.images.best.to_s
        }
        
        render json: data
      rescue => e
        # エラーが発生した場合はエラーレスポンスを返す
        render json: { error: e.message }, status: :unprocessable_entity
      end
    end
  end
end
