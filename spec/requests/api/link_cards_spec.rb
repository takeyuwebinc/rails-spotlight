require 'rails_helper'

RSpec.describe "Api::LinkCards", type: :request do
  describe "GET /api/link_cards/metadata" do
    context "with valid URL" do
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
      
      it "returns metadata as JSON" do
        get "/api/link_cards/metadata", params: { url: 'https://example.com' }
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['title']).to eq('Example Title')
        expect(json['description']).to eq('Example description')
        expect(json['domain']).to eq('example.com')
        expect(json['favicon']).to eq('https://example.com/favicon.ico')
        expect(json['imageUrl']).to eq('https://example.com/image.jpg')
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
    
    context "when metadata fetching fails" do
      before do
        allow(MetaInspector).to receive(:new).and_raise(StandardError.new("Failed to fetch metadata"))
      end
      
      it "returns error status" do
        get "/api/link_cards/metadata", params: { url: 'https://example.com' }
        
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to eq("Failed to fetch metadata")
      end
    end
  end
end
