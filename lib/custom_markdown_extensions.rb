require "cgi"

# カスタムMarkdown拡張機能モジュール
#
# このモジュールは、Redcarpetのレンダラーに拡張機能を追加するためのものです。
# 現在は、URLのみの行をリンクカードに変換する機能と、mermaid図表の描画機能を提供しています。
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
end
