require 'rails_helper'

RSpec.describe Tools::FindSlideTool do
  describe '.call' do
    let!(:published_slide) do
      create(:slide, :with_pages, :with_tags,
        slug: "test-slide",
        title: "Test Slide",
        description: "Test Description",
        published_at: Time.current - 1.day
      )
    end

    let!(:draft_slide) do
      create(:slide, :draft,
        slug: "draft-slide",
        title: "Draft Slide",
        published_at: Time.current + 1.day
      )
    end

    context 'with existing published slide' do
      it 'returns slide details' do
        response = described_class.call(slug: "test-slide", server_context: {})

        expect(response).to be_a(MCP::Tool::Response)
        expect(response.content.first[:type]).to eq("text")
        expect(response.content.first[:text]).to include("Slide found:")
        expect(response.content.first[:text]).to include("Test Slide")
        expect(response.content.first[:text]).to include("test-slide")
        expect(response.content.first[:text]).to include("Test Description")
        expect(response.content.first[:text]).to include("Pages: 3")
        expect(response.content.first[:text]).to include("Status: Published")
      end

      it 'includes public URL' do
        response = described_class.call(slug: "test-slide", server_context: {})

        expect(response.content.first[:text]).to include("URL: https://example.com/slides/test-slide")
      end
    end

    context 'with draft slide' do
      it 'shows draft status' do
        response = described_class.call(slug: "draft-slide", server_context: {})

        expect(response.content.first[:text]).to include("Status: Draft")
      end
    end

    context 'with non-existent slide' do
      it 'returns not found message' do
        response = described_class.call(slug: "non-existent", server_context: {})

        expect(response.content.first[:text]).to eq("Slide not found with slug: non-existent")
      end
    end

    context 'with exception' do
      before do
        allow(Slide).to receive(:find_by).and_raise(StandardError, "Database error")
      end

      it 'returns an error message' do
        response = described_class.call(slug: "test-slide", server_context: {})

        expect(response.content.first[:text]).to include("Error finding slide: Database error")
      end
    end
  end
end
