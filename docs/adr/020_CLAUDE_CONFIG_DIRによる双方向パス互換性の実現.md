# 020_CLAUDE_CONFIG_DIR による双方向パス互換性の実現

## ステータス

承認済み

## 日付

2026-03-09

## コンテキスト

[ADR 019](019_DevContainerでのClaude%20Code設定共有と動的パス解決.md) で、`remoteEnv` と動的シンボリックリンクにより Plugin Marketplace のパス問題を解決した。しかし、この方式はホスト→コンテナ方向のパス解決のみを実現しており、逆方向の問題が残っていた。

### 現状の問題点

- **コンテナでインストールしたプラグインがホストで使用できない**: コンテナ内で Plugin Marketplace からプラグインを追加すると、`known_marketplaces.json` の `installLocation` がコンテナのパス（`/home/vscode/.claude/plugins/...`）で記録される。ホスト側にはこのパスが存在しないため、プラグインを読み込めない
- **ADR 019 のシンボリックリンク方式は片方向**: ホストのパス（`/home/alice/.claude/...`）をコンテナ内で解決する仕組みであり、コンテナのパスをホスト側で解決する仕組みはない

### 制約条件

- ホスト側の設定ファイルに副作用を与えてはならない
- Dockerfile にホスト固有の情報を持ち込まない

## 決定

バインドマウント先をホストと同じパス（`${localEnv:HOME}/.claude`）に変更し、`CLAUDE_CONFIG_DIR` 環境変数でコンテナ内の Claude Code が同じパスを設定ディレクトリとして使用するようにする。これにより、ADR 019 のシンボリックリンク方式と `setup-claude-paths.sh` を廃止し、よりシンプルな構成で双方向のパス互換性を実現する。

### 実装方針

1. **バインドマウント先をホストのパスに変更**: `target=${localEnv:HOME}/.claude` とし、コンテナ内でもホストと同じ絶対パスにファイルが配置されるようにする
2. **`containerEnv` に `CLAUDE_CONFIG_DIR` を追加**: `${localEnv:HOME}/.claude` を設定し、コンテナ内の Claude Code がホストと同じパスで設定ディレクトリを参照するようにする。`remoteEnv` ではなく `containerEnv` を使用することで、`postCreateCommand` を含むコンテナ内のすべてのプロセスから参照可能にする
3. **シンボリックリンク方式を廃止**: `setup-claude-paths.sh` と `HOST_HOME` 環境変数を削除する

### パス解決の仕組み

ホストとコンテナで同一の絶対パスを使用するため、パス変換が不要になる。

| 環境 | 設定ディレクトリ | ファイルの実体 |
|---|---|---|
| ホスト | `/home/alice/.claude` | ホストのファイルシステム |
| コンテナ | `/home/alice/.claude`（`CLAUDE_CONFIG_DIR`） | バインドマウントによりホストと同一 |

どちらの環境でプラグインをインストールしても `/home/alice/.claude/...` というパスで記録されるため、もう一方の環境でもそのまま有効になる。

### `devcontainer.json` の変更

```json
{
  "mounts": [
    "source=${localEnv:HOME}/.claude,target=${localEnv:HOME}/.claude,type=bind,consistency=cached"
  ],
  "containerEnv": {
    "CLAUDE_CONFIG_DIR": "${localEnv:HOME}/.claude"
  },
  "postCreateCommand": "bin/claude-setup.sh && bin/setup --skip-server"
}
```

### 検証結果

コンテナ再構築後に以下を確認した。

- マウント先の親ディレクトリ（`/home/alice`）は Docker が `root:root`（`755`）で自動作成する。読み取り・トラバースは全ユーザーに許可されるため、`vscode` ユーザーからのアクセスに問題はない
- マウントされた `.claude` ディレクトリはホスト側の権限がそのまま反映され、`vscode` ユーザーで読み書き可能
- `CLAUDE_CONFIG_DIR` により Claude Code がホストと同じパスでプラグインを記録することを確認

## 結果

### ポジティブな影響

1. **双方向のパス互換性が実現される**
   - ホスト・コンテナ双方で同一の絶対パスを使用するため、パス変換が不要
   - どちらの環境でインストールしたプラグインも、もう一方でそのまま使用可能

2. **構成がシンプルになる**
   - `setup-claude-paths.sh` と動的シンボリックリンクが不要になる
   - `HOST_HOME` 環境変数も不要になる
   - パス解決の仕組みが1つ（同一パスへのマウント + `CLAUDE_CONFIG_DIR`）に統一される

### ネガティブな影響・トレードオフ

1. **`CLAUDE_CONFIG_DIR` の仕様への依存**
   - Claude Code がこの環境変数を公式にサポートしていることが前提となる
   - 対策: Claude Code の公式ドキュメント（Settings）に `CLAUDE_CONFIG_DIR` が記載されていることを確認済み

2. **コンテナ内にホスト依存のディレクトリ構造が作られる**
   - `/home/alice` のようなホストのホームディレクトリがコンテナ内に `root` 所有で作成される
   - 対策: 読み取り・トラバースのみ必要であり、`755` パーミッションで問題ないことを検証済み

## 代替案

### 案1: シンボリックリンク + CLAUDE_CONFIG_DIR（マウント先は /home/vscode/.claude のまま）

**概要**: ADR 019 のシンボリックリンク方式を維持し、`CLAUDE_CONFIG_DIR` を追加して逆方向のパス解決を実現する。

**メリット**:
- マウント先を変更しないため、既存構成への影響が少ない
- シンボリックリンクがホスト→コンテナ方向、`CLAUDE_CONFIG_DIR` がコンテナ→ホスト方向と役割分担が明確

**デメリット**:
- パス解決に2つの仕組み（シンボリックリンク + `CLAUDE_CONFIG_DIR`）が共存し、構成が複雑
- `setup-claude-paths.sh` と `HOST_HOME` の維持が必要

**却下理由**: マウント先をホストのパスに変更することで構成を単純化できることを検証で確認した

### 案2: 現状維持（シンボリックリンクのみ）

**概要**: ADR 019 の方式のまま、コンテナ→ホスト方向のパス問題は許容する。

**メリット**:
- 追加の設定変更が不要
- 既に動作実績がある

**デメリット**:
- コンテナでインストールしたプラグインがホストで使用できない

**却下理由**: プラグインの追加・更新をホスト・コンテナどちらからでも行えることが開発体験として望ましい

## 参考資料

- [ADR 019: Dev Container での Claude Code 設定共有と動的パス解決](019_DevContainerでのClaude%20Code設定共有と動的パス解決.md)
- [claude-code#10379 - Plugin marketplace paths hardcoded as absolute paths](https://github.com/anthropics/claude-code/issues/10379)
- [Claude Code - Settings（CLAUDE_CONFIG_DIR）](https://code.claude.com/docs/en/settings)
