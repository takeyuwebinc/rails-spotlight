require 'rails_helper'

RSpec.describe "Api::LinkCards", type: :request do
  describe "GET /api/link_cards/metadata" do
    context "with valid URL and no cache" do
      before do
        # MetaInspectorのモック
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

      it "returns metadata as JSON and creates cache" do
        expect {
          get "/api/link_cards/metadata", params: { url: 'https://example.com' }
        }.to change(LinkMetadatum, :count).by(1)

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['title']).to eq('Example Title')
        expect(json['description']).to eq('Example description')
        expect(json['domain']).to eq('example.com')
        expect(json['favicon']).to eq('https://example.com/favicon.ico')
        expect(json['imageUrl']).to eq('https://example.com/image.jpg')

        # キャッシュが作成されたことを確認
        cache = LinkMetadatum.find_by(url: 'https://example.com')
        expect(cache).to be_present
        expect(cache.title).to eq('Example Title')
      end
    end

    context "with cached metadata" do
      let!(:cached_metadata) do
        create(:link_metadatum, :valid,
          url: 'https://cached.com',
          title: 'Cached Title',
          description: 'Cached Description',
          domain: 'cached.com',
          favicon: 'https://cached.com/favicon.ico',
          image_url: 'https://cached.com/image.jpg'
        )
      end

      it "returns cached metadata without making external request" do
        # MetaInspectorがモックされていても呼ばれないことを確認
        expect(MetaInspector).not_to receive(:new)

        get "/api/link_cards/metadata", params: { url: 'https://cached.com' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['title']).to eq('Cached Title')
        expect(json['description']).to eq('Cached Description')
      end
    end

    context "with expired cache" do
      let!(:expired_metadata) do
        create(:link_metadatum, :expired,
          url: 'https://expired.com',
          title: 'Old Title',
          description: 'Old Description'
        )
      end

      before do
        # MetaInspectorのモック
        page = double('MetaInspector')
        allow(page).to receive_messages(
          title: 'New Title',
          best_description: 'New Description',
          host: 'expired.com',
          images: double(
            best: 'https://expired.com/new-image.jpg',
            favicon: 'https://expired.com/new-favicon.ico'
          )
        )
        allow(MetaInspector).to receive(:new).and_return(page)
      end

      it "fetches fresh metadata and updates cache" do
        get "/api/link_cards/metadata", params: { url: 'https://expired.com' }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['title']).to eq('New Title')

        # キャッシュが更新されたことを確認
        expired_metadata.reload
        expect(expired_metadata.title).to eq('New Title')
        expect(expired_metadata.last_fetched_at).to be > 1.minute.ago
      end
    end

    context "with missing URL" do
      it "returns bad request status" do
        get "/api/link_cards/metadata"

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json['error']).to be_present
      end
    end

    context "when metadata fetching fails with expected error" do
      before do
        allow(MetaInspector).to receive(:new).and_raise(MetaInspector::RequestError.new("Failed to fetch metadata"))
      end

      it "returns specific error message" do
        get "/api/link_cards/metadata", params: { url: 'https://example.com' }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to eq("Failed to fetch metadata")
      end
    end

    context "when metadata fetching fails with unexpected error" do
      before do
        allow(MetaInspector).to receive(:new).and_raise(StandardError.new("Unexpected error"))
        allow(Rails.error).to receive(:report)
      end

      it "reports error and returns generic error message" do
        get "/api/link_cards/metadata", params: { url: 'https://example.com' }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to eq("メタデータの取得中に問題が発生しました。しばらく経ってからもう一度お試しください。")
      end
    end
  end
end
