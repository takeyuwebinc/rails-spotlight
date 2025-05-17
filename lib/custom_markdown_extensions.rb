module CustomMarkdownExtensions
  # 拡張機能を登録するためのメソッド
  def self.register_extensions(renderer)
    LinkCardExtension.register(renderer)
  end
  
  # リンクカード拡張モジュール
  module LinkCardExtension
    def self.register(renderer)
      # 前処理フックを追加
      original_preprocess = renderer.method(:preprocess)
      
      renderer.define_singleton_method(:preprocess) do |document|
        # URLのみの行を検出してプレースホルダーに置き換え
        document = document.gsub(/^(https?:\/\/[^\s]+)$/m) do
          url = $1.strip
          # URLをdata属性に持つdivを生成（JavaScriptで検出するため）
          # 直接HTMLを出力する
          %(<div class="link-card-placeholder" data-controller="link-card" data-link-card-url-value="#{url}">
              <a href="#{url}" target="_blank" rel="noopener">#{url}</a>
            </div>)
        end
        
        # 元の前処理メソッドを呼び出す
        original_preprocess.call(document)
      end
    end
  end
end
