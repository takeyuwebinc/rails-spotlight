import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="syntax-highlight"
export default class extends Controller {
  connect() {
    // highlight.jsが読み込まれるまで待機
    this.waitForHighlightJs()
  }

  waitForHighlightJs() {
    if (typeof hljs !== 'undefined') {
      this.highlightAll()
    } else {
      // highlight.jsが読み込まれるまで少し待つ
      setTimeout(() => this.waitForHighlightJs(), 100)
    }
  }

  highlightAll() {
    // コードブロックを検索してハイライトを適用
    const codeBlocks = this.element.querySelectorAll('pre code')
    
    codeBlocks.forEach(block => {
      // 既にハイライト済みかチェック
      if (!block.classList.contains('hljs')) {
        hljs.highlightElement(block)
      }
    })
    
    console.log("Syntax highlighting applied to", codeBlocks.length, "code blocks")
  }

  // 動的にコンテンツが追加された場合の再ハイライト
  refresh() {
    this.highlightAll()
  }
}
