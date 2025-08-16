require 'rails_helper'

RSpec.describe Tools::CreateSlideTool do
  describe '.call' do
    let(:valid_content) do
      <<~MARKDOWN
        ---
        title: Test Slide Presentation
        slug: test-slide-presentation
        category: slide
        description: A test slide presentation
        published_date: 2025-08-16
        tags:
          - Ruby
          - Testing
        ---

        # First Slide

        This is the first slide content

        ---

        # Second Slide

        This is the second slide content
      MARKDOWN
    end

    let(:invalid_content) do
      <<~MARKDOWN
        ---
        title: Test Article
        slug: test-article
        category: article
        description: Not a slide
        published_date: 2025-08-16
        ---

        # Content

        This is not a slide
      MARKDOWN
    end

    context 'with valid slide content' do
      it 'creates a slide successfully' do
        response = described_class.call(content: valid_content, server_context: {})

        expect(response).to be_a(MCP::Tool::Response)
        expect(response.content.first[:type]).to eq("text")
        expect(response.content.first[:text]).to include("Slide created successfully:")
        expect(response.content.first[:text]).to include("Test Slide Presentation")
        expect(response.content.first[:text]).to include("test-slide-presentation")
        expect(response.content.first[:text]).to include("Pages: 2")
        expect(response.content.first[:text]).to include("Ruby, Testing")
      end

      it 'creates slide pages' do
        expect {
          described_class.call(content: valid_content, server_context: {})
        }.to change(Slide, :count).by(1)
          .and change(SlidePage, :count).by(2)
      end
    end

    context 'with invalid content' do
      it 'returns an error message' do
        response = described_class.call(content: invalid_content, server_context: {})

        expect(response.content.first[:text]).to include("Failed to create slide")
        expect(response.content.first[:text]).to include("category: slide")
      end
    end

    context 'with missing required fields' do
      let(:missing_fields_content) do
        <<~MARKDOWN
          ---
          title: Test Slide
          category: slide
          ---

          # Content
        MARKDOWN
      end

      it 'returns an error message' do
        response = described_class.call(content: missing_fields_content, server_context: {})

        expect(response.content.first[:text]).to include("Failed to create slide")
      end
    end

    context 'with exception' do
      before do
        allow(Slide).to receive(:import_from_markdown).and_raise(StandardError, "Test error")
      end

      it 'returns an error message' do
        response = described_class.call(content: valid_content, server_context: {})

        expect(response.content.first[:text]).to include("Error creating slide: Test error")
      end
    end
  end
end
