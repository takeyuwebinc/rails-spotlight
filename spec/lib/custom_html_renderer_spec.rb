require 'rails_helper'
require 'redcarpet'
# No need to require custom_html_renderer as it's autoloaded by Rails

RSpec.describe CustomHtmlRenderer do
  let(:renderer) { CustomHtmlRenderer.new(hard_wrap: true) }
  let(:markdown) do
    Redcarpet::Markdown.new(renderer, {
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      highlight: true,
      superscript: true,
      underline: true,
      quote: true
    })
  end

  describe '#render' do
    context 'with regular markdown' do
      let(:text) { "# Header\n\nRegular paragraph" }

      it 'renders standard markdown correctly' do
        result = markdown.render(text)
        expect(result).to include('<h1>Header</h1>')
        expect(result).to include('<p>Regular paragraph</p>')
      end
    end

    context 'with :::message syntax' do
      let(:text) do
        <<~MARKDOWN
        # Header

        :::message
        This is a message
        :::
        MARKDOWN
      end

      it 'renders message blocks correctly' do
        result = markdown.render(text)
        expect(result).to include('<div class="bg-amber-50 dark:bg-amber-900/20 border-l-4 border-amber-400 dark:border-amber-500 p-4 mb-4 rounded-r">')
        expect(result).to include('<p class="text-sm text-amber-800 dark:text-amber-200">This is a message</p>')
      end
    end

    context 'with :::message alert syntax' do
      let(:text) do
        <<~MARKDOWN
        # Header

        :::message alert
        This is an alert message
        :::
        MARKDOWN
      end

      it 'renders alert message blocks correctly' do
        result = markdown.render(text)
        expect(result).to include('<div class="bg-red-50 dark:bg-red-900/20 border-l-4 border-red-400 dark:border-red-500 p-4 mb-4 rounded-r">')
        expect(result).to include('<p class="text-sm text-red-800 dark:text-red-200">This is an alert message</p>')
        expect(result).not_to include('<svg class="h-5 w-5 text-red-400"')
      end
    end

    context 'with :::details syntax' do
      let(:text) do
        <<~MARKDOWN
        # Header

        :::details タイトル
        詳細内容
        :::
        MARKDOWN
      end

      it 'renders details blocks correctly' do
        result = markdown.render(text)
        expect(result).to include('<div class="border border-gray-200 dark:border-gray-700 rounded mb-4" data-controller="details"')
        expect(result).to include('<button data-action="click->details#toggle" class="flex justify-between items-center w-full p-4 text-left text-sm font-medium text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800 focus:outline-none">')
        expect(result).to include('<span>タイトル</span>')
        expect(result).to include('<div data-details-target="content" class="p-4 border-t border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800"')
        expect(result).to include('<p class="text-sm text-gray-600 dark:text-gray-400">詳細内容</p>')
      end
    end

    context 'with nested custom syntax' do
      let(:text) do
        <<~MARKDOWN
        # Header

        ::::details タイトル
        ここにテキスト

        :::message
        ネストされたメッセージ
        :::

        さらにテキスト
        ::::
        MARKDOWN
      end

      it 'renders nested blocks correctly' do
        result = markdown.render(text)

        # 詳細ブロックが存在することを確認
        expect(result).to include('<div class="border border-gray-200 dark:border-gray-700 rounded mb-4" data-controller="details">')
        expect(result).to include('<span>タイトル</span>')

        # 詳細ブロックの内容部分を抽出
        details_content = result.match(/<div data-details-target="content" class="p-4 border-t border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800">(.*?)<\/div><\/div>/m)
        expect(details_content).not_to be_nil

        # 詳細ブロック内にメッセージブロックが含まれていることを確認
        details_html = details_content[1]
        expect(details_html).to include('<div class="bg-amber-50 dark:bg-amber-900/20 border-l-4 border-amber-400 dark:border-amber-500 p-4 mb-4 rounded-r">')
        expect(details_html).to include('<p class="text-sm text-amber-800 dark:text-amber-200">ネストされたメッセージ</p>')
      end
    end

    context 'with multiple levels of nesting' do
      let(:text) do
        <<~MARKDOWN
        # Header

        ::::details 外側のタイトル
        外側のテキスト

        :::details 内側のタイトル
        内側のテキスト
        :::

        :::message
        内側のメッセージ
        :::

        外側の続き
        ::::
        MARKDOWN
      end

      it 'renders multiple levels of nesting correctly' do
        result = markdown.render(text)

        # 外側の詳細ブロックが存在することを確認
        expect(result).to include('<span>外側のタイトル</span>')

        # 外側の詳細ブロックの内容部分を抽出
        outer_details_content = result.match(/<div data-details-target="content" class="p-4 border-t border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800">(.*?)<\/div><\/div>/m)
        expect(outer_details_content).not_to be_nil

        # 内側の詳細ブロックが外側の詳細ブロック内にネストされていることを確認
        outer_html = outer_details_content[1]
        expect(outer_html).to include('<span>内側のタイトル</span>')

        # 内側のメッセージブロックが外側の詳細ブロック内にネストされていることを確認
        # 正規表現で全体のHTMLを検索
        expect(result).to match(/<div data-details-target="content" class="p-4 border-t border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800">.*?<div class="bg-amber-50 dark:bg-amber-900\/20 border-l-4 border-amber-400 dark:border-amber-500 p-4 mb-4 rounded-r">.*?<p class="text-sm text-amber-800 dark:text-amber-200">内側のメッセージ<\/p>/m)
      end
    end

    context 'with code blocks inside message' do
      let(:text) do
        <<~MARKDOWN
        # Header

        :::message
        コードブロック:

        ```ruby
        def hello
          puts "Hello, world!"
        end
        ```
        :::
        MARKDOWN
      end

      it 'renders code blocks inside message correctly' do
        result = markdown.render(text)
        expect(result).to include('<div class="bg-amber-50 dark:bg-amber-900/20 border-l-4 border-amber-400 dark:border-amber-500 p-4 mb-4 rounded-r">')
        expect(result).to include('<p class="text-sm text-amber-800 dark:text-amber-200">コードブロック:</p>')
        expect(result).to include('<code class="language-ruby">')
        expect(result).to include('def hello')
      end
    end

    context 'with code blocks inside details' do
      let(:text) do
        <<~MARKDOWN
        # Header

        :::details Rubyがインストールされている場合

        ```bash
        gem install kamal
        ```

        または bundle で導入

        ```bash
        bundle add kamal --group development
        ```
        :::
        MARKDOWN
      end

      it 'renders code blocks inside details correctly' do
        result = markdown.render(text)
        expect(result).to include('<div class="border border-gray-200 dark:border-gray-700 rounded mb-4" data-controller="details">')
        expect(result).to include('<span>Rubyがインストールされている場合</span>')
        expect(result).to include('<code class="language-bash">gem install kamal')
        expect(result).to include('<p class="text-sm text-gray-600 dark:text-gray-400">または bundle で導入</p>')
        expect(result).to include('<code class="language-bash">bundle add kamal --group development')
      end
    end

    context 'with many custom blocks' do
      it 'handles a large number of custom blocks correctly' do
        # Generate a markdown text with many custom blocks
        blocks = []
        20.times do |i|
          blocks << ":::message\nMessage #{i}\n:::"
        end
        text = "# Header\n\n#{blocks.join("\n\n")}"

        # Render the markdown
        result = markdown.render(text)

        # Check that all blocks are rendered correctly
        20.times do |i|
          expect(result).to include("<p class=\"text-sm text-amber-800 dark:text-amber-200\">Message #{i}</p>")
        end
      end
    end
  end
end
