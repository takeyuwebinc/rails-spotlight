require "rails_helper"
require "custom_markdown_extensions"

RSpec.describe CustomMarkdownExtensions::ImageExtension do
  describe ".register" do
    let(:renderer) { instance_double(CustomHtmlRenderer) }

    it "registers preprocessing and postprocessing methods" do
      # Mock the necessary methods to avoid errors
      allow(renderer).to receive(:method).and_return(->(*args) { })
      allow(renderer).to receive(:define_singleton_method)

      # Expect define_singleton_method to be called for preprocess and postprocess methods
      expect(renderer).to receive(:define_singleton_method).with(:preprocess).once
      expect(renderer).to receive(:define_singleton_method).with(:postprocess).once

      described_class.register(renderer)
    end
  end

  describe "integration with CustomHtmlRenderer" do
    let(:renderer) { CustomHtmlRenderer.new }
    let(:markdown) do
      Redcarpet::Markdown.new(renderer, {
        autolink: true,
        tables: true,
        fenced_code_blocks: true
      })
    end

    context "with basic image syntax" do
      let(:image_markdown) { "![Alt text](/path/to/image.jpg)" }

      it "renders a figure with image" do
        html = markdown.render(image_markdown)
        expect(html).to include('<figure class="my-6" id="img-')
        expect(html).to include('<img src="/path/to/image.jpg" alt="Alt text" class="max-w-full h-auto rounded-md mx-auto"')
        expect(html).to include('</figure>')
      end
    end

    context "with image width specification" do
      let(:image_markdown) { "![Alt text](/path/to/image.jpg =250px)" }

      it "renders an image with specified width" do
        html = markdown.render(image_markdown)
        expect(html).to include('style="width: 250px;"')
        expect(html).to include('alt="Alt text"')
        expect(html).to include('class="max-w-full h-auto rounded-md mx-auto"')
      end
    end

    context "with relative image path" do
      let(:image_markdown) { "![Alt text](image.jpg)" }

      it "converts relative path to assets path" do
        # Mock the ApplicationController.helpers.image_path method
        allow(ApplicationController.helpers).to receive(:image_path).with("image.jpg").and_return("/assets/image-a1b2c3d4e5f6.jpg")
        html = markdown.render(image_markdown)
        expect(html).to include('<img src="/assets/image-a1b2c3d4e5f6.jpg"')
      end
    end

    context "with image caption" do
      let(:image_markdown) do
        <<~MARKDOWN
          ![Alt text](/path/to/image.jpg)
          *This is a caption*
        MARKDOWN
      end

      it "renders an image with caption" do
        html = markdown.render(image_markdown)
        expect(html).to include('<figure class="my-6" id="img-')
        expect(html).to include('<img src="/path/to/image.jpg" alt="Alt text"')
        expect(html).to include('<figcaption class="text-sm text-gray-600 text-center mt-2">This is a caption</figcaption>')
      end
    end

    context "with linked image" do
      let(:image_markdown) { "[![Alt text](/path/to/image.jpg)](https://example.com)" }

      it "renders an image wrapped in a link" do
        html = markdown.render(image_markdown)
        expect(html).to include('<figure class="my-6" id="img-')
        expect(html).to include('<a href="https://example.com" target="_blank" rel="noopener">')
        expect(html).to include('<img src="/path/to/image.jpg" alt="Alt text"')
        expect(html).to include('</a>')
        expect(html).to include('</figure>')
      end
    end

    context "with URL image path" do
      let(:image_markdown) { "![Alt text](https://example.com/image.jpg)" }

      it "keeps the URL unchanged" do
        html = markdown.render(image_markdown)
        expect(html).to include('<img src="https://example.com/image.jpg"')
      end
    end

    context "with no alt text" do
      let(:image_markdown) { "![](/path/to/image.jpg)" }

      it "renders an image with empty alt text" do
        html = markdown.render(image_markdown)
        expect(html).to include('<img src="/path/to/image.jpg" alt="" class="max-w-full h-auto rounded-md mx-auto"')
      end
    end
  end
end
