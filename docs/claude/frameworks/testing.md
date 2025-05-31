# テスト標準

- ビジネスロジックのユニットテストが必要。
- Controllerについて、Request specs によるインテグレーションテストが必要。
- APIについて、rswag gem を使って spec から OpenAPI 3.0 Specification を作成する。

## E2Eテスト（Puppeteer）

### 環境について
- PuppeteerとChromiumは開発コンテナにインストール済み
- 追加のセットアップは不要

### テスト実行手順
```bash
 NODE_PATH=$(npm root -g) node tmp/tests/[テストファイル名].js
```

### テストファイルの場所
- `tmp/tests/test_navigation_display.js` - ナビゲーション表示テスト
- `tmp/tests/test_article_title_display.js` - 記事タイトル表示テスト

### スクリーンショット証跡
テスト実行時に自動的にスクリーンショットが撮影され、`tmp/screenshots/navigation_test_[タイムスタンプ]/` に保存されます：

- `01_desktop_navigation.png` - デスクトップナビゲーション表示
- `02_mobile_navigation_closed.png` - モバイルナビゲーション（閉じた状態）
- `03_mobile_navigation_opened.png` - モバイルナビゲーション（開いた状態）

### テスト作成の基本パターン
```javascript
const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

(async () => {
  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  
  const page = await browser.newPage();
  
  // スクリーンショット保存用のディレクトリ
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const screenshotDir = path.join('tmp', 'screenshots', `test_${timestamp}`);
  
  if (!fs.existsSync(screenshotDir)) {
    fs.mkdirSync(screenshotDir, { recursive: true });
  }
  
  try {
    await page.goto('http://localhost:3000', { 
      waitUntil: 'networkidle2',
      timeout: 10000 
    });
    
    // スクリーンショット撮影
    await page.screenshot({ 
      path: path.join(screenshotDir, 'screenshot.png'),
      fullPage: true 
    });
    
    // テストロジック
    
  } catch (error) {
    console.error('テストエラー:', error);
  } finally {
    await browser.close();
  }
})();
```
