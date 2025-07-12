require "securerandom"
require "cgi"
require_relative "custom_markdown_extensions"

class CustomHtmlRenderer < Redcarpet::Render::HTML
  attr_reader :placeholders, :block_code_handlers

  def initialize(options = {})
    super
    @placeholders = {}
    @block_code_handlers = []

    # 拡張機能を登録
    CustomMarkdownExtensions.register_extensions(self)
  end

  # コードブロックのレンダリングをカスタマイズ
  def block_code(code, language)
    # 登録されたハンドラを順に試す
    @block_code_handlers.each do |handler|
      result = handler.call(code, language)
      return result if result # ハンドラが処理した場合はその結果を返す
    end

    # どのハンドラも処理しなかった場合はデフォルト処理
    %(<pre><code class="#{language}">#{CGI.escape_html(code)}</code></pre>)
  end

  # ブロックコードハンドラを登録するメソッド
  def register_block_code_handler(handler)
    @block_code_handlers << handler
  end

  # noautolinkクラスを持つ要素内のリンクを自動生成しないようにする
  #
  # @param link [String] 変換対象のリンクURL
  # @param link_type [Symbol] リンクの種類（:email, :url）
  # @return [String] 変換後のHTML
  # @note このメソッドは、noautolinkクラスを持つ要素内のリンクを自動生成しないようにします。
  #   これにより、リンクカード内のURLが二重にリンクされるのを防ぎます。
  def autolink(link, link_type)
    # 現在処理中のテキストがnoautolinkクラスを持つ要素内かどうかを確認
    if @in_noautolink
      link
    else
      %(<a href="#{link}">#{link}</a>)
    end
  end

  # HTMLタグを処理する際にnoautolinkクラスを検出
  #
  # @param html [String] 処理対象のHTML
  # @return [String] 処理後のHTML
  # @note このメソッドは、HTMLタグを処理する際にnoautolinkクラスを検出し、
  #   そのクラスを持つ要素内のリンクを自動生成しないようにします。
  def preprocess_html_block(html)
    if html.include?("noautolink")
      @in_noautolink = true
      result = super
      @in_noautolink = false
      result
    else
      super
    end
  end

  # リンクを処理する前にnoautolinkクラスを検出
  #
  # @param link [String] 処理対象のリンク
  # @return [String] 処理後のリンク
  # @note このメソッドは、リンクを処理する前にnoautolinkクラスを検出し、
  #   そのクラスを持つ要素内のリンクを自動生成しないようにします。
  def preprocess_link(link)
    if link.include?("noautolink")
      @in_noautolink = true
      result = super
      @in_noautolink = false
      result
    else
      super
    end
  end

  def preprocess(document)
    @placeholders = {}
    convert_custom_blocks_to_placeholder(document)
  end

  def postprocess(document)
    convert_custom_placeholder_to_html(document)
  end

  private

  def convert_custom_blocks_to_placeholder(text)
    # Process ::::details blocks (4 colons for outer blocks)
    text = text.gsub(/^::::details\s+(.+?)\s*$\n(.*?)^::::\s*$/m) do
      title = $1.strip
      content = $2
      placeholder = SecureRandom.uuid

      placeholders[placeholder] = {
        type: :details,
        title: title,
        content: content
      }

      placeholder
    end

    # Process :::details blocks (3 colons for regular or inner blocks)
    text = text.gsub(/^:::details\s+(.+?)\s*$\n(.*?)^:::\s*$/m) do
      title = $1.strip
      content = $2
      placeholder = SecureRandom.uuid

      placeholders[placeholder] = {
        type: :details,
        title: title,
        content: content
      }

      placeholder
    end

    # Process ::::message blocks (4 colons for outer blocks)
    text = text.gsub(/^::::message\s*$\n(.*?)^::::\s*$/m) do
      content = $1
      placeholder = SecureRandom.uuid

      placeholders[placeholder] = {
        type: :message,
        content: content
      }

      placeholder
    end

    # Process :::message blocks (3 colons for regular or inner blocks)
    text = text.gsub(/^:::message\s*$\n(.*?)^:::\s*$/m) do
      content = $1
      placeholder = SecureRandom.uuid

      placeholders[placeholder] = {
        type: :message,
        content: content
      }

      placeholder
    end

    # Process ::::message alert blocks (4 colons for outer blocks)
    text = text.gsub(/^::::message\s+alert\s*$\n(.*?)^::::\s*$/m) do
      content = $1
      placeholder = SecureRandom.uuid

      placeholders[placeholder] = {
        type: :message_alert,
        content: content
      }

      placeholder
    end

    # Process :::message alert blocks (3 colons for regular or inner blocks)
    text = text.gsub(/^:::message\s+alert\s*$\n(.*?)^:::\s*$/m) do
      content = $1
      placeholder = SecureRandom.uuid

      placeholders[placeholder] = {
        type: :message_alert,
        content: content
      }

      placeholder
    end

    # Process :::rating blocks
    text = text.gsub(/^:::rating\s+(\d+)(?:\s+(.+?))?\s*$/) do
      rating = $1.to_i
      description = $2
      placeholder = SecureRandom.uuid

      placeholders[placeholder] = {
        type: :rating,
        rating: rating,
        description: description
      }

      placeholder
    end

    text
  end

  def convert_custom_placeholder_to_html(text)
    # Now recursively process placeholders
    placeholders.each do |placeholder, data|
      # Render the content with Redcarpet (if content exists)
      html_content = render_markdown(data[:content]) if data[:content]

      # Generate the final HTML based on the block type
      final_html = case data[:type]
      when :details
        # Wrap content in a paragraph with the appropriate class if it's not already wrapped
        content_with_class = if html_content.strip.start_with?("<p")
                              html_content.gsub(/<p>/, '<p class="text-sm text-gray-600 dark:text-gray-400">')
        else
                              "<p class=\"text-sm text-gray-600 dark:text-gray-400\">#{html_content}</p>"
        end

        %(<div class="border border-gray-200 dark:border-gray-700 rounded mb-4" data-controller="details"><button data-action="click->details#toggle" class="flex justify-between items-center w-full p-4 text-left text-sm font-medium text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800 focus:outline-none"><span>#{data[:title]}</span><svg class="h-5 w-5 text-gray-500 dark:text-gray-400 transition-transform duration-200" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clip-rule="evenodd" /></svg></button><div data-details-target="content" class="p-4 border-t border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800">#{content_with_class}</div></div>)
      when :message
        # Wrap content in a paragraph with the appropriate class if it's not already wrapped
        content_with_class = if html_content.strip.start_with?("<p")
                              html_content.gsub(/<p>/, '<p class="text-sm text-amber-800 dark:text-amber-200">')
        else
                              "<p class=\"text-sm text-amber-800 dark:text-amber-200\">#{html_content}</p>"
        end

        %(<div class="bg-amber-50 dark:bg-amber-900/20 border-l-4 border-amber-400 dark:border-amber-500 p-4 mb-4 rounded-r">#{content_with_class}</div>)
      when :message_alert
        # Wrap content in a paragraph with the appropriate class if it's not already wrapped
        content_with_class = if html_content.strip.start_with?("<p")
                              html_content.gsub(/<p>/, '<p class="text-sm text-red-800 dark:text-red-200">')
        else
                              "<p class=\"text-sm text-red-800 dark:text-red-200\">#{html_content}</p>"
        end

        %(<div class="bg-red-50 dark:bg-red-900/20 border-l-4 border-red-400 dark:border-red-500 p-4 mb-4 rounded-r">#{content_with_class}</div>)
      when :rating
        # Generate star rating
        rating = data[:rating].to_i
        rating = [ [ rating, 1 ].max, 5 ].min # Clamp between 1 and 5

        filled_stars = "★" * rating
        empty_stars = "☆" * (5 - rating)
        stars = filled_stars + empty_stars

        # Build the rating HTML
        rating_html = %(<span class="rating-stars text-xl text-amber-600 dark:text-amber-400">#{stars}</span>)
        rating_html += %(<span class="rating-number text-gray-600 dark:text-gray-400">（#{rating}/5）</span>)
        rating_html += %(<span class="rating-description"> - #{data[:description]}</span>) if data[:description]

        %(<div class="rating-block mb-2">#{rating_html}</div>)
      end

      # Replace the placeholder with the final HTML
      text.gsub!(placeholder) { final_html }
      text.gsub!("<p><div ") { "<div " }
      text.gsub!("</div></p>") { "</div>" }
    end
    text
  end

  def render_markdown(text)
    # Create a new Redcarpet instance to render inner content
    renderer = CustomHtmlRenderer.new(hard_wrap: true)
    markdown = Redcarpet::Markdown.new(renderer, {
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      highlight: true,
      superscript: true,
      underline: true,
      quote: true
    })

    # Convert inner content from markdown to HTML
    markdown.render(text)
  end
end
