require 'rails_helper'

RSpec.describe Tools::ListSlidesTool do
  describe '.call' do
    let!(:published_slide1) do
      create(:slide, :with_pages,
        title: "Published Slide 1",
        slug: "published-1",
        published_at: 2.days.ago
      )
    end

    let!(:published_slide2) do
      create(:slide, :with_pages,
        title: "Published Slide 2",
        slug: "published-2",
        published_at: 1.day.ago
      )
    end

    let!(:draft_slide) do
      create(:slide, :draft,
        title: "Draft Slide",
        slug: "draft-1",
        published_at: 1.day.from_now
      )
    end

    let!(:tagged_slide) do
      slide = create(:slide, :with_pages,
        title: "Tagged Slide",
        slug: "tagged-1",
        published_at: 3.hours.ago
      )
      tag = create(:tag, name: "Ruby", slug: "ruby")
      slide.tags << tag
      slide
    end

    context 'listing all slides' do
      it 'returns all slides' do
        response = described_class.call(server_context: {})

        expect(response).to be_a(MCP::Tool::Response)
        expect(response.content.first[:text]).to include("Found 4 slide(s)")
        expect(response.content.first[:text]).to include("Published Slide 1")
        expect(response.content.first[:text]).to include("Published Slide 2")
        expect(response.content.first[:text]).to include("Draft Slide")
        expect(response.content.first[:text]).to include("Tagged Slide")
      end
    end

    context 'filtering by published status' do
      it 'returns only published slides' do
        response = described_class.call(status: "published", server_context: {})

        expect(response.content.first[:text]).to include("Found 3 slide(s)")
        expect(response.content.first[:text]).to include("Published Slide 1")
        expect(response.content.first[:text]).to include("Published Slide 2")
        expect(response.content.first[:text]).to include("Tagged Slide")
        expect(response.content.first[:text]).not_to include("Draft Slide")
      end
    end

    context 'filtering by draft status' do
      it 'returns only draft slides' do
        response = described_class.call(status: "draft", server_context: {})

        expect(response.content.first[:text]).to include("Found 1 slide(s)")
        expect(response.content.first[:text]).to include("Draft Slide")
        expect(response.content.first[:text]).not_to include("Published Slide")
      end
    end

    context 'filtering by tag' do
      it 'returns slides with specific tag' do
        response = described_class.call(tag_slug: "ruby", server_context: {})

        expect(response.content.first[:text]).to include("Found 1 slide(s)")
        expect(response.content.first[:text]).to include("Tagged Slide")
        expect(response.content.first[:text]).to include("Tags: Ruby")
      end
    end

    context 'with no slides found' do
      it 'returns appropriate message' do
        response = described_class.call(tag_slug: "non-existent", server_context: {})

        expect(response.content.first[:text]).to eq("No slides found with the specified criteria.")
      end
    end

    context 'slide details' do
      it 'includes all required information' do
        response = described_class.call(status: "published", server_context: {})

        text = response.content.first[:text]
        expect(text).to include("Slug:")
        expect(text).to include("URL:")
        expect(text).to include("Pages:")
        expect(text).to include("Status:")
        expect(text).to include("Published at:")
        expect(text).to include("Tags:")
      end

      it 'includes public URL for each slide' do
        response = described_class.call(status: "published", server_context: {})

        text = response.content.first[:text]
        expect(text).to include("URL: https://example.com/slides/published-1")
        expect(text).to include("URL: https://example.com/slides/published-2")
        expect(text).to include("URL: https://example.com/slides/tagged-1")
      end
    end

    context 'with exception' do
      before do
        allow(Slide).to receive(:all).and_raise(StandardError, "Database error")
      end

      it 'returns an error message' do
        response = described_class.call(server_context: {})

        expect(response.content.first[:text]).to include("Error listing slides: Database error")
      end
    end
  end
end
