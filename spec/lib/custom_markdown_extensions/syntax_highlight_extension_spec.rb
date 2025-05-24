require 'rails_helper'
require 'custom_markdown_extensions'

RSpec.describe CustomMarkdownExtensions::SyntaxHighlightExtension do
  let(:renderer) { CustomHtmlRenderer.new }
  let(:markdown) do
    Redcarpet::Markdown.new(renderer, {
      autolink: true,
      tables: true,
      fenced_code_blocks: true
    })
  end

  describe '.parse_language_and_filename' do
    it 'parses language with filename' do
      lang, filename = described_class.send(:parse_language_and_filename, 'bash:~/.bash_profile')
      expect(lang).to eq('bash')
      expect(filename).to eq('~/.bash_profile')
    end

    it 'parses language without filename' do
      lang, filename = described_class.send(:parse_language_and_filename, 'bash')
      expect(lang).to eq('bash')
      expect(filename).to be_nil
    end

    it 'handles empty filename' do
      lang, filename = described_class.send(:parse_language_and_filename, 'bash:')
      expect(lang).to eq('bash')
      expect(filename).to be_nil
    end

    it 'handles filename with multiple colons' do
      lang, filename = described_class.send(:parse_language_and_filename, 'bash:C:\\Users\\file.bat')
      expect(lang).to eq('bash')
      expect(filename).to eq('C:\\Users\\file.bat')
    end

    it 'handles whitespace around language and filename' do
      lang, filename = described_class.send(:parse_language_and_filename, ' ruby : app/models/user.rb ')
      expect(lang).to eq('ruby')
      expect(filename).to eq('app/models/user.rb')
    end
  end

  describe '.generate_code_block_with_filename' do
    it 'generates HTML with filename display' do
      html = described_class.send(:generate_code_block_with_filename, 'echo "OK"', 'bash', '~/.bash_profile')

      expect(html).to include('class="code-block-container relative"')
      expect(html).to include('class="code-filename absolute top-0 left-0 bg-gray-700 text-gray-200 text-xs px-3 py-1 rounded-tl-md rounded-br-md font-mono z-10"')
      expect(html).to include('~/.bash_profile')
      expect(html).to include('class="language-bash"')
      expect(html).to include('echo &quot;OK&quot;')
      expect(html).to include('pt-8') # padding-top for filename space
    end

    it 'escapes HTML in filename' do
      html = described_class.send(:generate_code_block_with_filename, 'echo "OK"', 'bash', '<script>alert("xss")</script>')

      expect(html).to include('&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;')
      expect(html).not_to include('<script>alert("xss")</script>')
    end

    it 'escapes HTML in code content' do
      html = described_class.send(:generate_code_block_with_filename, '<script>alert("xss")</script>', 'bash', 'test.sh')

      expect(html).to include('&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;')
      expect(html).not_to include('<script>alert("xss")</script>')
    end
  end

  describe '.generate_code_block' do
    it 'generates standard HTML without filename' do
      html = described_class.send(:generate_code_block, 'echo "OK"', 'bash')

      expect(html).to include('<pre class="not-prose">')
      expect(html).to include('class="language-bash"')
      expect(html).to include('echo &quot;OK&quot;')
      expect(html).not_to include('code-filename')
      expect(html).not_to include('pt-8')
    end

    it 'escapes HTML in code content' do
      html = described_class.send(:generate_code_block, '<script>alert("xss")</script>', 'bash')

      expect(html).to include('&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;')
      expect(html).not_to include('<script>alert("xss")</script>')
    end
  end

  describe 'integration with markdown renderer' do
    context 'with filename syntax' do
      let(:markdown_text) do
        <<~MARKDOWN
          # Test

          ```bash:~/.bash_profile
          echo "Hello World"
          export PATH=$PATH:/usr/local/bin
          ```

          Regular text.
        MARKDOWN
      end

      it 'renders code block with filename display' do
        result = markdown.render(markdown_text)

        expect(result).to include('class="code-block-container relative"')
        expect(result).to include('class="code-filename')
        expect(result).to include('~/.bash_profile')
        expect(result).to include('class="language-bash"')
        expect(result).to include('echo &quot;Hello World&quot;')
        expect(result).to include('export PATH=$PATH:/usr/local/bin')
      end
    end

    context 'without filename syntax' do
      let(:markdown_text) do
        <<~MARKDOWN
          # Test

          ```bash
          echo "Hello World"
          export PATH=$PATH:/usr/local/bin
          ```

          Regular text.
        MARKDOWN
      end

      it 'renders standard code block without filename display' do
        result = markdown.render(markdown_text)

        expect(result).to include('<pre class="not-prose">')
        expect(result).to include('class="language-bash"')
        expect(result).to include('echo &quot;Hello World&quot;')
        expect(result).to include('export PATH=$PATH:/usr/local/bin')
        expect(result).not_to include('code-filename')
        expect(result).not_to include('code-block-container')
      end
    end

    context 'with various filename formats' do
      it 'handles Unix-style paths' do
        markdown_text = "```ruby:app/models/user.rb\nclass User\nend\n```"
        result = markdown.render(markdown_text)

        expect(result).to include('app/models/user.rb')
        expect(result).to include('class="language-ruby"')
      end

      it 'handles Windows-style paths' do
        markdown_text = "```batch:C:\\Windows\\System32\\script.bat\necho \"Windows\"\n```"
        result = markdown.render(markdown_text)

        expect(result).to include('C:\\Windows\\System32\\script.bat')
        expect(result).to include('class="language-batch"')
      end

      it 'handles relative paths' do
        markdown_text = "```javascript:../config/webpack.config.js\nmodule.exports = {}\n```"
        result = markdown.render(markdown_text)

        expect(result).to include('../config/webpack.config.js')
        expect(result).to include('class="language-javascript"')
      end

      it 'handles filenames with special characters' do
        markdown_text = "```python:my-file_name.py\nprint(\"hello\")\n```"
        result = markdown.render(markdown_text)

        expect(result).to include('my-file_name.py')
        expect(result).to include('class="language-python"')
      end
    end

    context 'edge cases' do
      it 'handles empty language with colon' do
        markdown_text = "```:filename.txt\nsome content\n```"
        result = markdown.render(markdown_text)

        expect(result).to include('filename.txt')
        expect(result).to include('some content')
      end

      it 'handles language with empty filename' do
        markdown_text = "```bash:\necho \"test\"\n```"
        result = markdown.render(markdown_text)

        expect(result).to include('<pre class="not-prose">')
        expect(result).to include('class="language-bash"')
        expect(result).not_to include('code-filename')
      end

      it 'handles multiple colons in filename' do
        markdown_text = "```yaml:docker-compose.yml:backup\nversion: \"3\"\n```"
        result = markdown.render(markdown_text)

        expect(result).to include('docker-compose.yml:backup')
        expect(result).to include('class="language-yaml"')
      end
    end

    context 'HTML escaping' do
      it 'escapes HTML in filename' do
        markdown_text = "```bash:<script>alert(\"xss\")</script>\necho \"test\"\n```"
        result = markdown.render(markdown_text)

        expect(result).to include('&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;')
        expect(result).not_to include('<script>alert("xss")</script>')
      end

      it 'escapes HTML in code content' do
        markdown_text = "```html:index.html\n<script>alert(\"xss\")</script>\n```"
        result = markdown.render(markdown_text)

        expect(result).to include('&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;')
        # The filename should still be displayed normally
        expect(result).to include('>index.html<')
      end
    end
  end
end
