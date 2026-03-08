# 019_Dev Container での Claude Code 設定共有と動的パス解決

## ステータス

承認済み

## 日付

2026-03-08

## コンテキスト

[ADR 018](018_DevContainer継続利用とPlugin%20Marketplace%20パス問題の対応.md) で Dev Container の継続利用と Plugin Marketplace パス問題へのワークアラウンド対応を決定した。ADR 018 では具体的な実装方式として、ハードコードされたシンボリックリンクと `sed` による書き換えの2案を併記していたが、いずれにも課題があった。

### 現状の問題点

- **ハードコード方式**（ADR 018 の案1）: `postStartCommand` に `/home/yuichi` をハードコードするため、他のチームメンバーの環境で動作しない
- **`sed` 書き換え方式**（ADR 018 の案2）: バインドマウントのためホスト側の `known_marketplaces.json` も書き換わり、ホスト環境に副作用がある

### 制約条件

- `known_marketplaces.json` のパス形式は Claude Code 側の仕様であり変更できない
- コンテナのデフォルトユーザーは `vscode`（ベースイメージ `ghcr.io/rails/devcontainer/images/ruby` の仕様）
- ホスト側の設定ファイルに副作用を与えてはならない
- チームメンバーのホストユーザー名は各自異なる

## 決定

`devcontainer.json` の `remoteEnv` でホストの `$HOME` をコンテナに伝搬し、セットアップスクリプトで動的にシンボリックリンクを作成する方式を採用する。

### 実装方針

1. **`~/.claude/` と `~/.claude.json` をバインドマウント**して、ホストの認証情報・プラグイン設定をコンテナと共有する
2. **`remoteEnv` で `HOST_HOME` 環境変数を設定**し、ホストの `$HOME` をコンテナに伝搬する（`${localEnv:HOME}` はビルド時にホスト側で解決される）
3. **`.devcontainer/setup-claude-paths.sh` を `postCreateCommand` で実行**し、`HOST_HOME` → `HOME` のシンボリックリンクを動的に作成する

#### 設定ファイルの役割分担

| パス | 管理方法 | 用途 |
|---|---|---|
| `~/.claude/` | ホストからバインドマウント | 認証情報・プラグイン等の個人設定 |
| `~/.claude.json` | ホストからバインドマウント | グローバル設定 |
| `.claude/` | Git管理（リポジトリ内） | プロジェクト固有の設定・指示（チーム共有） |

#### `devcontainer.json` の追加設定

```json
{
  "mounts": [
    "source=${localEnv:HOME}/.claude,target=/home/vscode/.claude,type=bind,consistency=cached",
    "source=${localEnv:HOME}/.claude.json,target=/home/vscode/.claude.json,type=bind,consistency=cached"
  ],
  "remoteEnv": {
    "HOST_HOME": "${localEnv:HOME}"
  },
  "postCreateCommand": ".devcontainer/setup-claude-paths.sh && bin/claude-setup.sh && bin/setup --skip-server"
}
```

#### `.devcontainer/setup-claude-paths.sh`

```bash
#!/bin/bash
set -e

# ホームが一致していれば何もしない（CI環境等）
[ "$HOST_HOME" = "$HOME" ] && exit 0
[ -z "$HOST_HOME" ] && exit 0

# ホストの $HOME パスがコンテナ内で解決できるようシンボリックリンクを作成
HOST_HOME_PARENT=$(dirname "$HOST_HOME")
sudo mkdir -p "$HOST_HOME_PARENT"
sudo ln -sfn "$HOME" "$HOST_HOME"

echo "Symlinked $HOST_HOME -> $HOME"
```

#### 動作例

| ホスト環境 | `HOST_HOME` | コンテナ内の動作 |
|---|---|---|
| `/home/yuichi` | `/home/yuichi` | `/home/yuichi` → `/home/vscode` のシンボリックリンク作成 |
| `/home/bob`（別マシン） | `/home/bob` | `/home/bob` → `/home/vscode` のシンボリックリンク作成 |
| CI（`/root`） | `/root` | `HOST_HOME = HOME` のためスキップ |

## 結果

### ポジティブな影響

1. **ポータビリティが確保される**
   - `${localEnv:HOME}` と `remoteEnv` により、ホストユーザー名をハードコードしない
   - チームメンバーが異なるユーザー名でも動作する

2. **ホスト側に副作用がない**
   - `known_marketplaces.json` を書き換えず、コンテナ内のシンボリックリンクのみで解決する

3. **CI 環境で自動スキップされる**
   - `HOST_HOME = HOME`（ともに `/root`）の場合は何もしない

### ネガティブな影響・トレードオフ

1. **Claude Code 側の修正までワークアラウンドの維持が必要**
   - [#10379](https://github.com/anthropics/claude-code/issues/10379) が修正されればこの対応は不要になる
   - 対策: 修正後にスクリプトを削除するだけで済む（`HOST_HOME = HOME` の場合は自動スキップ）

2. **`sudo` 権限が必要**
   - シンボリックリンク作成にホームディレクトリ外への書き込みが必要
   - 対策: Dev Container のデフォルト構成では `vscode` ユーザーに `sudo` が付与されている

## 代替案

### 案1: ユーザー名ハードコードによるシンボリックリンク（ADR 018 の案1）

**概要**: `postStartCommand` に `sudo ln -sfn /home/vscode/.claude /home/yuichi/.claude` をハードコードする。

**メリット**:
- 実装が最もシンプル
- 追加のスクリプトファイルが不要

**デメリット**:
- ホストユーザー名がハードコードされるため、他のチームメンバーの環境で動作しない

**却下理由**: ポータビリティが確保できない

### 案2: `sed` によるパス書き換え（ADR 018 の案2）

**概要**: `postCreateCommand` で `known_marketplaces.json` 内のパスを `sed` で書き換える。

**メリット**:
- シンボリックリンクより直接的な解決方法
- ファイルシステム上の追加構造が不要

**デメリット**:
- バインドマウントのため、ホスト側の `known_marketplaces.json` も書き換わる
- ホストとコンテナを交互に使う場合、双方向の変換が必要

**却下理由**: ホスト側に副作用があり、ホスト環境での Claude Code 動作に影響を与えるリスクがある

## 参考資料

- [ADR 018: Dev Container 継続利用と Plugin Marketplace パス問題の対応](018_DevContainer継続利用とPlugin%20Marketplace%20パス問題の対応.md)
- [claude-code#10379 - Plugin marketplace paths hardcoded as absolute paths](https://github.com/anthropics/claude-code/issues/10379)
