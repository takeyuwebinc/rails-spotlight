require 'rails_helper'
require 'custom_markdown_extensions'

RSpec.describe CustomMarkdownExtensions do
  describe 'LinkCardExtension' do
    let(:renderer) { CustomHtmlRenderer.new }
    let(:markdown) do
      Redcarpet::Markdown.new(renderer, {
        autolink: true,
        tables: true,
        fenced_code_blocks: true
      })
    end
    
    context 'with URL-only line' do
      let(:text) { "# Header\n\nhttps://example.com\n\nRegular paragraph" }
      
      it 'converts URL to link card placeholder' do
        result = markdown.render(text)
        expect(result).to include('class="link-card-placeholder"')
        expect(result).to include('data-controller="link-card"')
        expect(result).to include('data-link-card-url-value="https://example.com"')
        expect(result).to include('<a href="https://example.com" target="_blank" rel="noopener">https://example.com</a>')
      end
    end
    
    context 'with URL in regular paragraph' do
      let(:text) { "# Header\n\nThis is a paragraph with https://example.com in it." }
      
      it 'does not convert URL to link card placeholder' do
        result = markdown.render(text)
        expect(result).not_to include('class="link-card-placeholder"')
        expect(result).to include('<a href="https://example.com">https://example.com</a>')
      end
    end
  end
end
