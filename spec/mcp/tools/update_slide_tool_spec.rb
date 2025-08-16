require 'rails_helper'

RSpec.describe Tools::UpdateSlideTool do
  describe '.call' do
    let!(:existing_slide) { create(:slide, slug: "existing-slide", title: "Old Title") }

    let(:updated_content) do
      <<~MARKDOWN
        ---
        title: Updated Slide Title
        slug: existing-slide
        category: slide
        description: Updated description
        published_date: 2025-08-20
        tags:
          - Updated
          - Tags
        ---

        # Updated First Slide

        New content for first slide

        ---

        # Updated Second Slide

        New content for second slide
      MARKDOWN
    end

    context 'with existing slide' do
      it 'updates the slide successfully' do
        response = described_class.call(
          slug: "existing-slide",
          content: updated_content,
          server_context: {}
        )

        expect(response).to be_a(MCP::Tool::Response)
        expect(response.content.first[:type]).to eq("text")
        expect(response.content.first[:text]).to include("Slide updated successfully:")
        expect(response.content.first[:text]).to include("Updated Slide Title")
        expect(response.content.first[:text]).to include("Pages: 2")
        expect(response.content.first[:text]).to include("Updated, Tags")
      end

      it 'updates the slide in the database' do
        described_class.call(
          slug: "existing-slide",
          content: updated_content,
          server_context: {}
        )

        updated_slide = Slide.find_by(slug: "existing-slide")
        expect(updated_slide.title).to eq("Updated Slide Title")
        expect(updated_slide.description).to eq("Updated description")
        expect(updated_slide.slide_pages.count).to eq(2)
      end
    end

    context 'with non-existent slide' do
      it 'returns not found message' do
        response = described_class.call(
          slug: "non-existent",
          content: updated_content,
          server_context: {}
        )

        expect(response.content.first[:text]).to eq("Slide not found with slug: non-existent")
      end
    end

    context 'with invalid content' do
      let(:invalid_content) do
        <<~MARKDOWN
          ---
          title: Invalid
          category: article
          ---

          # Content
        MARKDOWN
      end

      it 'returns an error message' do
        response = described_class.call(
          slug: "existing-slide",
          content: invalid_content,
          server_context: {}
        )

        expect(response.content.first[:text]).to include("Failed to update slide")
      end
    end

    context 'with exception' do
      before do
        allow(Slide).to receive(:import_from_markdown).and_raise(StandardError, "Update error")
      end

      it 'returns an error message' do
        response = described_class.call(
          slug: "existing-slide",
          content: updated_content,
          server_context: {}
        )

        expect(response.content.first[:text]).to include("Error updating slide: Update error")
      end
    end
  end
end
