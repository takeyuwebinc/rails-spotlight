# 018_Dev Container 継続利用と Plugin Marketplace パス問題の対応

## ステータス

承認済み

## 日付

2026-03-08

## コンテキスト

Dev Container 環境で Claude Code を使用する際、Plugin Marketplace のパス問題（[#10379](https://github.com/anthropics/claude-code/issues/10379)）が発生している。`~/.claude/plugins/known_marketplaces.json` にプラグインの場所が絶対パスで保存されるため、ホスト（`/home/yuichi/`）とコンテナ（`/home/vscode/`）のユーザー名の差異により `ENOENT` エラーが発生する。

この問題を機に、Dev Container を廃止して「ホスト編集 + コンテナ実行」パターンへの移行を検討した。調査の結果（[調査報告書](../reports/dev-container-to-container-execution.md)）、以下が判明した。

### Dev Container を廃止した場合の課題

1. **ruby-lsp がリモート LSP 非対応**（[ruby-lsp#480](https://github.com/Shopify/ruby-lsp/issues/480)）。ホストの VS Code からコンテナ内の LSP にネットワーク越しに接続できない。「Attach to Running Container」で回避できるが、その場合 Claude Code 拡張もコンテナ内で動作し、同じ問題が再発する。
2. **ruby-debug のリモートデバッグ**は TCP 経由で可能だが、LSP と合わせて使うには構成が複雑になる。
3. **VS Code 拡張版 Claude Code の機能損失**。ホスト CLI 版では画像ドラッグ&ドロップ、インライン diff、IDE コンテキスト（開いているファイル・選択範囲・診断情報）が使えない。
4. **UID/GID マッピング**の問題。Docker では `ARG UID` パターン、Podman では `--userns=keep-id` が必要で、named volume との組合せに既知の問題がある。

### Dev Container を維持した場合

上記すべての問題が発生しない。ruby-lsp、デバッガ、Claude Code 拡張のフル機能がそのまま使える。解決すべき問題は Plugin Marketplace の絶対パスのみに絞られる。

## 決定

Dev Container を継続利用し、Plugin Marketplace のパス問題はコンテナ側のワークアラウンドで対応する。

### 対応方法: `postStartCommand` でシンボリックリンクを作成

コンテナ起動時にホストユーザーのホームディレクトリへのシンボリックリンクを作成し、`known_marketplaces.json` 内の絶対パスをそのまま解決可能にする。

```json
{
  "postStartCommand": "sudo mkdir -p /home/yuichi && sudo ln -sfn /home/vscode/.claude /home/yuichi/.claude"
}
```

あるいは、汎用的に `initializeCommand` や `postCreateCommand` で `known_marketplaces.json` のパスを書き換える方法も考えられる。

```json
{
  "postStartCommand": "sed -i \"s|/home/yuichi/|/home/vscode/|g\" /home/vscode/.claude/plugins/known_marketplaces.json 2>/dev/null || true"
}
```

いずれの方法も、コンテナ側の設定変更のみで完結し、ホスト側に影響を与えない。

## 結果

### ポジティブ

- VS Code 拡張版 Claude Code のフル機能（画像入力、インライン diff、IDE コンテキスト）が維持される
- ruby-lsp、ruby-debug がそのまま動作する
- 既存の `devcontainer.json` の変更が最小限で済む
- UID/GID マッピングの問題を回避できる
- チームメンバーの学習コストが発生しない

### ネガティブ

- ホストユーザー名がハードコードされたワークアラウンドとなる（シンボリックリンク方式の場合）
- Claude Code 側で問題が修正されるまでワークアラウンドの維持が必要
- sed 方式の場合、ホスト側の `known_marketplaces.json` が書き換わらないため、ホストとコンテナで交互に使う場合は双方向の変換が必要

## 代替案

### A案: Dev Container 廃止 + ホスト編集 + コンテナ実行パターン

Evil Martians「Ruby on Whales」パターンに基づき、ソースコード編集と Claude Code はホストで動作させ、Rails 実行のみコンテナに委譲する。

**不採用の理由**:
- ruby-lsp がリモート LSP 非対応のため、LSP を使うには「Attach to Container」が必要。その場合 Claude Code 拡張もコンテナ内で動作し、元の問題が再発する
- ホスト CLI 版 Claude Code では画像入力やインライン diff 等の VS Code 拡張固有機能が失われる
- UID/GID マッピング、named volume の管理など新たな複雑性が生じる
- 解決される問題（Plugin Marketplace パス）に対して、導入される複雑性が大きすぎる

### B案: Dev Container のリモートユーザーをホストと揃える

`remoteUser` をホストユーザーと同じにすることでパスの不一致を解消する。

**不採用の理由**:
- Dev Container のベースイメージ（`ghcr.io/rails/devcontainer/images/ruby`）のデフォルトユーザーは `vscode` であり、変更するとパーミッション問題が発生する可能性がある
- チームメンバー間でホストユーザー名が異なる場合に対応できない

### C案: マウント先をホストと同じパスにする

`target=/home/yuichi/.claude` のように、コンテナ内のマウント先をホストの絶対パスと一致させる。

**不採用の理由**:
- B案と同様、チームメンバー間でホストパスが異なる場合に対応できない
- コンテナ内に `/home/yuichi/` ディレクトリを作成する必要があり、ベースイメージのユーザー構成と矛盾する

## 参考資料

- [調査報告書: Dev Container 廃止に向けたコンテナ実行環境の調査](../reports/dev-container-to-container-execution.md)
- [claude-code#10379 - Plugin marketplace paths hardcoded as absolute paths](https://github.com/anthropics/claude-code/issues/10379)
- [claude-code#6139 - Hardcoded /home/node/.config path](https://github.com/anthropics/claude-code/issues/6139)
- [ruby-lsp#480 - Docker/VM host setup](https://github.com/Shopify/ruby-lsp/issues/480)
