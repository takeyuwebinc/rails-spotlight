require "cgi"

# カスタムMarkdown拡張機能モジュール
#
# このモジュールは、Redcarpetのレンダラーに拡張機能を追加するためのものです。
# 現在は、URLのみの行をリンクカードに変換する機能、mermaid図表の描画機能、
# および拡張画像表示機能を提供しています。
module CustomMarkdownExtensions
  # 拡張機能をレンダラーに登録する
  #
  # @param renderer [Redcarpet::Render::HTML] 拡張機能を登録するレンダラー
  # @return [void]
  # @example
  #   CustomMarkdownExtensions.register_extensions(renderer)
  def self.register_extensions(renderer)
    LinkCardExtension.register(renderer)
    MermaidExtension.register(renderer)
    ImageExtension.register(renderer)
    SyntaxHighlightExtension.register(renderer)
  end

  # リンクカード拡張モジュール
  #
  # このモジュールは、URLのみの行をリンクカードに変換する機能を提供します。
  module LinkCardExtension
    # リンクカード拡張機能をレンダラーに登録する
    #
    # @param renderer [Redcarpet::Render::HTML] 拡張機能を登録するレンダラー
    # @return [void]
    # @example
    #   LinkCardExtension.register(renderer)
    def self.register(renderer)
      # 前処理フックを追加
      original_preprocess = renderer.method(:preprocess)

      renderer.define_singleton_method(:preprocess) do |document|
        # URLのみの行を検出してプレースホルダーに置き換え
        document = document.gsub(/^(https?:\/\/[^\s]+)$/m) do
          url = $1.strip
          # URLをdata属性に持つdivを生成（JavaScriptで検出するため）
          # 直接HTMLを出力する
          # noautolinkクラスを追加し、URLをエスケープして二重リンクを防止
          %(<div class="link-card-placeholder noautolink" data-controller="link-card" data-link-card-url-value="#{url}">
              <a href="#{url}" target="_blank" rel="noopener">#{url.gsub(/https?:\/\//, 'https&#58;//')}</a>
            </div>)
        end

        # 元の前処理メソッドを呼び出す
        original_preprocess.call(document)
      end
    end
  end

  # Mermaid図表拡張モジュール
  #
  # このモジュールは、Mermaid構文で記述されたコードブロックを図表として描画する機能を提供します。
  module MermaidExtension
    # Mermaid拡張機能をレンダラーに登録する
    #
    # @param renderer [Redcarpet::Render::HTML] 拡張機能を登録するレンダラー
    # @return [void]
    # @example
    #   MermaidExtension.register(renderer)
    def self.register(renderer)
      # block_codeハンドラを登録
      renderer.register_block_code_handler(
        lambda do |code, language|
          if language == "mermaid"
            # Mermaid図表用のHTMLを生成
            escaped_code = CGI.escape_html(code)
            %(<div class="mermaid-diagram" data-controller="mermaid">
                <pre class="mermaid-source" style="display: none;">#{escaped_code}</pre>
                <div class="mermaid-render"></div>
              </div>)
          else
            nil # このハンドラでは処理しない
          end
        end
      )
    end
  end

  # 画像表示拡張モジュール
  #
  # このモジュールは、Markdown内の画像構文を拡張し、幅指定やキャプションなどの
  # 追加機能をサポートします。
  module ImageExtension
    # 画像拡張機能をレンダラーに登録する
    #
    # @param renderer [Redcarpet::Render::HTML] 拡張機能を登録するレンダラー
    # @return [void]
    # @example
    #   ImageExtension.register(renderer)
    def self.register(renderer)
      # 元のimageメソッドを保存
      if renderer.respond_to?(:image)
        original_image = renderer.method(:image)
      end

      # 元のpreprocessメソッドを保存
      if renderer.respond_to?(:preprocess)
        original_preprocess = renderer.method(:preprocess)
      else
        original_preprocess = ->(document) { document }
      end

      # 前処理フックを追加（キャプション検出用）
      renderer.define_singleton_method(:preprocess) do |document|
        # キャプションを検出して処理
        document = document.gsub(/!\[(.*?)\]\((.*?)\)[ \t]*\n\*(.*?)\*/) do
          alt_text = $1
          image_path = $2
          caption_text = $3.strip

          # 画像IDを生成
          image_id = "img-#{SecureRandom.hex(6)}"

          # 幅指定を抽出
          width = nil
          clean_path = image_path
          if image_path =~ /\s*=\s*(\d+)px\s*$/
            width = $1.to_i
            clean_path = image_path.gsub(/\s*=\s*\d+px\s*$/, "").strip
          end

          # ImagePathResolverを使用してパスを解決
          resolver = ImagePathResolver.new(clean_path)
          resolved_path = resolver.call

          # 幅指定がある場合はスタイルを追加
          width_style = width ? %( style="width: #{width}px;") : ""

          # 画像とキャプションを含むHTMLを生成
          %(<figure class="my-6" id="#{image_id}">
  <img src="#{resolved_path}" alt="#{alt_text}" class="max-w-full h-auto rounded-md mx-auto"#{width_style} />
  <figcaption class="text-sm text-gray-600 text-center mt-2">#{caption_text}</figcaption>
</figure>)
        end

        # 元の前処理メソッドを呼び出す
        original_preprocess.call(document)
      end

      # 元のpostprocessメソッドを保存
      if renderer.respond_to?(:postprocess)
        original_postprocess = renderer.method(:postprocess)
      else
        original_postprocess = ->(document) { document }
      end

      # 後処理フックを追加（画像の処理）
      renderer.define_singleton_method(:postprocess) do |document|
        # リンク付き画像を検出して処理
        document = document.gsub(/<p><a href="([^"]+)"><img src="([^"]+)" alt="([^"]*)"[^>]*><\/a><\/p>/) do
          link_url = $1
          img_src = $2
          alt_text = $3

          # 画像IDを生成
          image_id = "img-#{SecureRandom.hex(6)}"

          # 幅指定を抽出
          width = nil
          clean_path = img_src
          if img_src =~ /\s*=\s*(\d+)px\s*$/
            width = $1.to_i
            clean_path = img_src.gsub(/\s*=\s*\d+px\s*$/, "").strip
          end

          # ImagePathResolverを使用してパスを解決
          resolver = ImagePathResolver.new(clean_path)
          resolved_path = resolver.call

          # 幅指定がある場合はスタイルを追加
          width_style = width ? %( style="width: #{width}px;") : ""

          # リンク付き画像を生成
          %(<figure class="my-6" id="#{image_id}">
  <a href="#{link_url}" target="_blank" rel="noopener">
    <img src="#{resolved_path}" alt="#{alt_text}" class="max-w-full h-auto rounded-md mx-auto"#{width_style} />
  </a>
</figure>)
        end

        # 通常の画像を検出して処理（既に処理済みのfigure要素は除外）
        document = document.gsub(/<p><img src="([^"]+)" alt="([^"]*)"[^>]*><\/p>/) do
          img_src = $1
          alt_text = $2

          # 既にfigure要素内にある場合はスキップ
          next $& if $`.include?("<figure") && !$`.include?("</figure>")

          # 画像IDを生成
          image_id = "img-#{SecureRandom.hex(6)}"

          # 幅指定を抽出
          width = nil
          clean_path = img_src
          if img_src =~ /\s*=\s*(\d+)px\s*$/
            width = $1.to_i
            clean_path = img_src.gsub(/\s*=\s*\d+px\s*$/, "").strip
          end

          # ImagePathResolverを使用してパスを解決
          resolver = ImagePathResolver.new(clean_path)
          resolved_path = resolver.call

          # 幅指定がある場合はスタイルを追加
          width_style = width ? %( style="width: #{width}px;") : ""

          # 画像を生成
          %(<figure class="my-6" id="#{image_id}">
  <img src="#{resolved_path}" alt="#{alt_text}" class="max-w-full h-auto rounded-md mx-auto"#{width_style} />
</figure>)
        end

        # 元の後処理メソッドを呼び出す
        original_postprocess.call(document)
      end
    end
  end

  # シンタックスハイライト拡張モジュール
  #
  # このモジュールは、コードブロックにシンタックスハイライト機能を提供します。
  module SyntaxHighlightExtension
    # シンタックスハイライト拡張機能をレンダラーに登録する
    #
    # @param renderer [Redcarpet::Render::HTML] 拡張機能を登録するレンダラー
    # @return [void]
    # @example
    #   SyntaxHighlightExtension.register(renderer)
    def self.register(renderer)
      # block_codeハンドラを登録
      renderer.register_block_code_handler(
        lambda do |code, language|
          if language.present?
            # highlight.js用のHTMLを生成
            %(<pre class="not-prose"><code class="language-#{CGI.escape_html(language)}">#{CGI.escape_html(code)}</code></pre>)
          else
            nil # このハンドラでは処理しない
          end
        end
      )
    end
  end
end
