require 'rails_helper'

RSpec.describe CustomHtmlRenderer, type: :lib do
  let(:renderer) { CustomHtmlRenderer.new }
  let(:markdown) { Redcarpet::Markdown.new(renderer, fenced_code_blocks: true) }

  describe 'syntax highlighting' do
    context 'with language specified' do
      it 'adds language class to code block' do
        input = <<~MARKDOWN
          ```ruby
          def hello
            puts "Hello, World!"
          end
          ```
        MARKDOWN

        result = markdown.render(input)

        expect(result).to include('<pre class="not-prose"><code class="language-ruby">')
        expect(result).to include('def hello')
        expect(result).to include('puts &quot;Hello, World!&quot;')
        expect(result).to include('</code></pre>')
      end

      it 'handles JavaScript code blocks' do
        input = <<~MARKDOWN
          ```javascript
          function hello() {
            console.log('Hello, World!');
          }
          ```
        MARKDOWN

        result = markdown.render(input)

        expect(result).to include('<pre class="not-prose"><code class="language-javascript">')
        expect(result).to include('function hello()')
        expect(result).to include("console.log(&#39;Hello, World!&#39;);")
      end

      it 'handles bash/shell code blocks' do
        input = <<~MARKDOWN
          ```bash
          gem install kamal
          bundle exec rails server
          ```
        MARKDOWN

        result = markdown.render(input)

        expect(result).to include('<pre class="not-prose"><code class="language-bash">')
        expect(result).to include('gem install kamal')
        expect(result).to include('bundle exec rails server')
      end

      it 'handles JSON code blocks' do
        input = <<~MARKDOWN
          ```json
          {
            "name": "test",
            "version": "1.0.0"
          }
          ```
        MARKDOWN

        result = markdown.render(input)

        expect(result).to include('<pre class="not-prose"><code class="language-json">')
        expect(result).to include('&quot;name&quot;: &quot;test&quot;')
        expect(result).to include('&quot;version&quot;: &quot;1.0.0&quot;')
      end

      it 'handles YAML code blocks' do
        input = <<~MARKDOWN
          ```yaml
          name: test
          version: 1.0.0
          ```
        MARKDOWN

        result = markdown.render(input)

        expect(result).to include('<pre class="not-prose"><code class="language-yaml">')
        expect(result).to include('name: test')
        expect(result).to include('version: 1.0.0')
      end
    end

    context 'without language specified' do
      it 'creates code block without language class' do
        input = <<~MARKDOWN
          ```
          some code without language
          ```
        MARKDOWN

        result = markdown.render(input)

        expect(result).to include('<pre><code class="">')
        expect(result).to include('some code without language')
      end
    end

    context 'with inline code' do
      it 'does not add language class to inline code' do
        input = 'This is `inline code` in a sentence.'

        result = markdown.render(input)

        expect(result).to include('<code>inline code</code>')
        expect(result).not_to include('class="language-')
      end
    end

    context 'with multiple code blocks' do
      it 'handles multiple code blocks with different languages' do
        input = <<~MARKDOWN
          ```ruby
          def ruby_method
            puts "Ruby"
          end
          ```

          ```javascript
          function jsFunction() {
            console.log("JavaScript");
          }
          ```

          ```
          plain code block
          ```
        MARKDOWN

        result = markdown.render(input)

        expect(result).to include('<pre class="not-prose"><code class="language-ruby">')
        expect(result).to include('<pre class="not-prose"><code class="language-javascript">')
        expect(result).to include('<pre><code class="">')
        expect(result).to include('def ruby_method')
        expect(result).to include('function jsFunction()')
        expect(result).to include('plain code block')
      end
    end

    context 'with special characters in code' do
      it 'properly escapes HTML entities' do
        input = <<~MARKDOWN
          ```html
          <div class="example">
            <p>Hello & goodbye</p>
          </div>
          ```
        MARKDOWN

        result = markdown.render(input)

        expect(result).to include('<pre class="not-prose"><code class="language-html">')
        expect(result).to include('&lt;div class=&quot;example&quot;&gt;')
        expect(result).to include('&lt;p&gt;Hello &amp; goodbye&lt;/p&gt;')
        expect(result).to include('&lt;/div&gt;')
      end
    end

    context 'integration with custom blocks' do
      it 'works within details blocks' do
        input = <<~MARKDOWN
          :::details Ruby installation
          ```bash
          gem install kamal
          ```
          :::
        MARKDOWN

        result = markdown.render(input)

        expect(result).to include('data-controller="details"')
        expect(result).to include('<pre class="not-prose"><code class="language-bash">')
        expect(result).to include('gem install kamal')
      end

      it 'works within message blocks' do
        input = <<~MARKDOWN
          :::message
          Here's some code:

          ```ruby
          puts "Hello"
          ```
          :::
        MARKDOWN

        result = markdown.render(input)

        expect(result).to include('bg-amber-50')
        expect(result).to include('<pre class="not-prose"><code class="language-ruby">')
        expect(result).to include('puts &quot;Hello&quot;')
      end
    end
  end

  describe 'code block structure' do
    it 'adds not-prose class to pre elements with language' do
      input = <<~MARKDOWN
        ```ruby
        def test
        end
        ```
      MARKDOWN

      result = markdown.render(input)
      expect(result).to include('<pre class="not-prose">')
    end

    it 'does not add not-prose class to pre elements without language' do
      input = <<~MARKDOWN
        ```
        plain code
        ```
      MARKDOWN

      result = markdown.render(input)
      expect(result).to include('<pre><code')
      expect(result).not_to include('class="not-prose"')
    end

    it 'preserves language information in class attribute' do
      languages = %w[ruby javascript python java go rust]

      languages.each do |lang|
        input = "```#{lang}\ncode\n```"
        result = markdown.render(input)
        expect(result).to include("class=\"language-#{lang}\"")
      end
    end
  end
end
