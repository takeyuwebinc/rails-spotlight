# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Link Cards API', type: :request do
  path '/api/link_cards/metadata' do
    get 'URLからメタデータを取得する' do
      tags 'Link Cards'
      description 'URLからメタデータ（タイトル、説明、ドメイン、ファビコン、画像URL）を取得します。キャッシュがある場合はキャッシュから取得し、ない場合は外部サイトから取得します。'
      produces 'application/json'
      parameter name: :url, in: :query, type: :string, required: true, description: 'メタデータを取得するURL'

      response '200', 'メタデータの取得に成功' do
        schema type: :object,
          properties: {
            title: { type: :string, description: 'ページのタイトル' },
            description: { type: :string, description: 'ページの説明' },
            domain: { type: :string, description: 'ドメイン名' },
            favicon: { type: :string, description: 'ファビコンのURL' },
            imageUrl: { type: :string, description: '代表画像のURL' }
          },
          required: [ 'title', 'description', 'domain' ]

        let(:url) { 'https://example.com' }

        before do
          # MetaInspectorのモック設定
          page = double('MetaInspector')
          allow(page).to receive_messages(
            title: 'Example Title',
            best_description: 'Example description',
            host: 'example.com',
            images: double(
              best: 'https://example.com/image.jpg',
              favicon: 'https://example.com/favicon.ico'
            )
          )
          allow(MetaInspector).to receive(:new).and_return(page)
        end

        run_test!
      end

      response '400', 'URLパラメータが不足している' do
        schema type: :object,
          properties: {
            error: { type: :string, description: 'エラーメッセージ' }
          },
          required: [ 'error' ]

        let(:url) { nil }

        run_test!
      end

      response '422', 'メタデータの取得に失敗' do
        schema type: :object,
          properties: {
            error: { type: :string, description: 'エラーメッセージ' }
          },
          required: [ 'error' ]

        let(:url) { 'https://example.com' }

        before do
          allow(MetaInspector).to receive(:new).and_raise(MetaInspector::RequestError.new("Failed to fetch metadata"))
        end

        run_test!
      end
    end
  end
end
