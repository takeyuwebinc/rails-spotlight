import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "toc", "tocMobile"]

  connect() {
    console.log("Table of Contents controller connected")
    console.log("Content target exists:", this.hasContentTarget)
    console.log("Toc target exists:", this.hasTocTarget)
    console.log("TocMobile target exists:", this.hasTocMobileTarget)
    
    this.generateTableOfContents()
    
    // スクロール監視を設定
    this.intersectionObserver = new IntersectionObserver(
      this.handleIntersection.bind(this),
      {
        rootMargin: '-20px 0px -80% 0px'
      }
    )
    
    // 全ての見出しを監視
    this.headings = this.contentTarget.querySelectorAll('h2, h3, h4, h5, h6')
    console.log("Found headings:", this.headings.length)
    this.headings.forEach(heading => {
      this.intersectionObserver.observe(heading)
    })
  }
  
  disconnect() {
    if (this.intersectionObserver) {
      this.intersectionObserver.disconnect()
    }
  }

  generateTableOfContents() {
    // 記事コンテンツから見出しを抽出
    const headings = this.contentTarget.querySelectorAll('h2, h3, h4, h5, h6')
    if (headings.length === 0) {
      console.log("No headings found in content")
      return
    }
    
    console.log("Generating table of contents with", headings.length, "headings")

    // 目次のHTMLを生成
    const tocList = document.createElement('ul')
    tocList.className = 'space-y-2 text-sm'

    headings.forEach((heading, index) => {
      // 見出しにIDを付与（スクロール用）
      const headingId = `heading-${index}`
      heading.id = headingId
      
      console.log("Processing heading:", heading.textContent, "with tag", heading.tagName)

      // 目次項目を作成
      const listItem = document.createElement('li')
      listItem.className = this.getIndentClassForHeading(heading)

      const link = document.createElement('a')
      link.href = `#${headingId}`
      link.className = 'text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-gray-200'
      link.textContent = heading.textContent
      link.addEventListener('click', (e) => {
        e.preventDefault()
        heading.scrollIntoView({ behavior: 'smooth' })
      })

      listItem.appendChild(link)
      tocList.appendChild(listItem)
    })

    // デスクトップ用の目次を表示
    if (this.hasTocTarget) {
      console.log("Updating desktop TOC")
      this.tocTarget.innerHTML = ''
      this.tocTarget.appendChild(tocList.cloneNode(true))
    } else {
      console.log("Desktop TOC target not found")
    }
    
    // モバイル用の目次を表示（存在する場合）
    if (this.hasTocMobileTarget) {
      console.log("Updating mobile TOC")
      this.tocMobileTarget.innerHTML = ''
      this.tocMobileTarget.appendChild(tocList.cloneNode(true))
    } else {
      console.log("Mobile TOC target not found")
    }
  }

  getIndentClassForHeading(heading) {
    // 見出しレベルに応じたインデントクラスを返す
    switch (heading.tagName) {
      case 'H2': return 'ml-0 font-medium'
      case 'H3': return 'ml-4'
      case 'H4': return 'ml-8'
      case 'H5': return 'ml-12'
      case 'H6': return 'ml-16'
      default: return 'ml-0'
    }
  }
  
  handleIntersection(entries) {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        // 現在表示されている見出しに対応する目次項目をハイライト
        const id = entry.target.id
        
        // デスクトップ版の目次をハイライト
        if (this.hasTocTarget) {
          const tocItems = this.tocTarget.querySelectorAll('a')
          let activeItem = null
          
          tocItems.forEach(item => {
            if (item.getAttribute('href') === `#${id}`) {
              item.classList.add('font-medium', 'text-blue-600', 'dark:text-blue-400')
              activeItem = item
            } else {
              item.classList.remove('font-medium', 'text-blue-600', 'dark:text-blue-400')
            }
          })
          
          // ハイライトされた項目が見えるようにスクロール
          if (activeItem) {
            // 目次コンテナの表示領域の情報を取得
            const container = this.tocTarget
            const containerRect = container.getBoundingClientRect()
            const activeItemRect = activeItem.getBoundingClientRect()
            
            // 項目が表示領域外にある場合はスクロール
            if (activeItemRect.top < containerRect.top || activeItemRect.bottom > containerRect.bottom) {
              // 項目が中央に来るようにスクロール
              const scrollTop = activeItem.offsetTop - (container.clientHeight / 2) + (activeItem.clientHeight / 2)
              container.scrollTo({
                top: Math.max(0, scrollTop),
                behavior: 'smooth'
              })
            }
          }
        }
        
        // モバイル版の目次をハイライト（存在する場合）
        if (this.hasTocMobileTarget) {
          const mobileTocItems = this.tocMobileTarget.querySelectorAll('a')
          let activeMobileItem = null
          
          mobileTocItems.forEach(item => {
            if (item.getAttribute('href') === `#${id}`) {
              item.classList.add('font-medium', 'text-blue-600', 'dark:text-blue-400')
              activeMobileItem = item
            } else {
              item.classList.remove('font-medium', 'text-blue-600', 'dark:text-blue-400')
            }
          })
          
          // モバイル版でもハイライトされた項目が見えるようにスクロール
          if (activeMobileItem && this.tocMobileTarget.closest('details[open]')) {
            const mobileContainer = this.tocMobileTarget
            const mobileContainerRect = mobileContainer.getBoundingClientRect()
            const activeMobileItemRect = activeMobileItem.getBoundingClientRect()
            
            if (activeMobileItemRect.top < mobileContainerRect.top || activeMobileItemRect.bottom > mobileContainerRect.bottom) {
              const scrollTop = activeMobileItem.offsetTop - (mobileContainer.clientHeight / 2) + (activeMobileItem.clientHeight / 2)
              mobileContainer.scrollTo({
                top: Math.max(0, scrollTop),
                behavior: 'smooth'
              })
            }
          }
        }
      }
    })
  }
}
