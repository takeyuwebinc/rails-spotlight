require "rails_helper"
require "custom_markdown_extensions"

RSpec.describe CustomMarkdownExtensions::MermaidExtension do
  describe ".register" do
    let(:renderer) { instance_double(CustomHtmlRenderer) }

    it "registers a block_code handler" do
      expect(renderer).to receive(:register_block_code_handler)
      described_class.register(renderer)
    end
  end

  describe "integration with CustomHtmlRenderer" do
    let(:renderer) { CustomHtmlRenderer.new }
    let(:markdown) { Redcarpet::Markdown.new(renderer, fenced_code_blocks: true) }

    context "with mermaid code block" do
      let(:mermaid_markdown) do
        <<~MARKDOWN
          ```mermaid
          graph TD;
              A-->B;
              A-->C;
              B-->D;
              C-->D;
          ```
        MARKDOWN
      end

      it "renders a mermaid diagram container" do
        html = markdown.render(mermaid_markdown)
        expect(html).to include('<div class="mermaid-diagram" data-controller="mermaid">')
        expect(html).to include('<pre class="mermaid-source" style="display: none;">')
        expect(html).to include('<div class="mermaid-render"></div>')
        expect(html).to include('graph TD;')
        expect(html).not_to include('</div></pre>')
      end
    end

    context "with regular code block" do
      let(:regular_markdown) do
        <<~MARKDOWN
          ```ruby
          def hello
            puts "Hello, world!"
          end
          ```
        MARKDOWN
      end

      it "renders a regular code block" do
        html = markdown.render(regular_markdown)
        expect(html).to include('<pre><code class="ruby">')
        expect(html).to include('def hello')
        expect(html).not_to include('mermaid-diagram')
      end
    end
  end
end
