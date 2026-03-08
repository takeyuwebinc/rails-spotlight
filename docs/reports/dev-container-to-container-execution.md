# Dev Container廃止に向けたコンテナ実行環境の調査

**作成日**: 2026/03/08
**ステータス**: Draft

## 概要

### 調査の背景

現在、開発環境としてDev Containerを使用しているが、Claude Code等のAIコーディングエージェントとの相性に問題がある（[anthropics/claude-code#10379](https://github.com/anthropics/claude-code/issues/10379)）。一方で、開発にはミドルウェアやネイティブ拡張のビルド依存など、ホスト環境を汚染する要素が多い。Dev Containerを廃止しつつ、ホスト汚染を防ぎ、AI生成コードの安全な実行を実現する方法を検討する必要がある。

### 調査の目的

Docker または Podman を使用して「ホスト編集 + コンテナ実行」パターンの適用可能性を明らかにする。具体的には以下を調査する。

1. ミドルウェア（PostgreSQL, Redis等）のコンテナ化パターン
2. ネイティブ拡張を持つgem（mysql2, pg等）のビルド依存をホストに入れずに済む方法
3. システムテスト（Capybara + Selenium）のコンテナ実行
4. UID/GIDマッピングの挙動と解決策
5. Docker vs Podman の比較
6. Claude Code等のAIエージェントとの連携
7. VS Code IDE機能（LSP、デバッガ）のコンテナ環境での利用

### 調査範囲

- **対象**: Docker, Podman を使った開発環境コンテナ化パターン
- **対象外**: Dev Container自体の改善、CI/CD環境の構成、本番デプロイ構成

## 調査内容

### 調査対象

- Evil Martians「Ruby on Whales」パターンおよびdipツール
- Docker / Podman のbind mount、named volume、UID/GID マッピング挙動
- Selenium/Chromium コンテナでのシステムテスト実行
- Claude Code のサンドボックス機能
- VS Code のRuby LSP（ruby-lsp, solargraph）およびruby-debug（rdbg）のコンテナ環境での動作

### 調査方法

- 公式ドキュメント・技術記事の文献調査
- Docker / Podman のUID/GIDマッピング仕様の分析
- 既存プロジェクト（spotlight-rails）の構成分析

## 調査結果

### 1. 「ホスト編集 + コンテナ実行」パターン

Dev Containerとの構造的な違いは以下の通り。

```
ホスト編集 + コンテナ実行:
┌─────────────────────┐     ┌─────────────────────────┐
│     ホスト            │     │      コンテナ群           │
│ - エディタ / IDE     │     │ [rails]                  │
│ - Claude Code        │     │   Ruby + ビルド依存全部    │
│ - ソースコード ──────┼────▶│   bundle, server, test   │
│                     │     │ [postgres] [redis] [chrome]│
│ 必要なもの:          │     │   ミドルウェア群           │
│   Docker/Podman のみ │     │                          │
└─────────────────────┘     └─────────────────────────┘
```

| 観点 | Dev Container | ホスト編集 + コンテナ実行 |
|------|--------------|------------------------|
| IDE実行場所 | コンテナ内（VS Code Remote） | ホスト（制約なし） |
| AIエージェント | コンテナ内（問題あり） | ホスト（問題なし） |
| コマンド実行 | コンテナ内で直接 | `docker compose exec` 経由 |
| エディタ選択 | 主にVS Code | 制約なし |
| ホスト必要物 | Docker のみ | Docker のみ（同等） |
| ファイル編集速度 | bind mount経由 | ホスト直接（高速） |

ソースコードはbind mountでコンテナに共有し、Claude Codeやエディタはホストでファイルを直接読み書きする。コマンド実行のみコンテナに委譲する構成となる。

### 2. ミドルウェアのコンテナ化

PostgreSQL、Redis等のサーバープロセスをcomposeで定義し、ホストの`127.0.0.1`にポートマッピングする。

```yaml
services:
  postgres:
    image: postgres:17-alpine
    volumes:
      - postgresql:/var/lib/postgresql/data:delegated
    ports:
      - "127.0.0.1:5432:5432"
    environment:
      POSTGRES_USER: app
      POSTGRES_HOST_AUTH_METHOD: trust
    healthcheck:
      test: pg_isready -U app -h 127.0.0.1
      interval: 5s

  redis:
    image: redis:7-alpine
    ports:
      - "127.0.0.1:6379:6379"
    healthcheck:
      test: redis-cli ping
      interval: 5s
```

Railsの`database.yml`からは`ENV.fetch("DB_HOST", "127.0.0.1")`で接続先を指定する。`127.0.0.1`バインドによりセキュリティを確保し、`trust`認証で開発時のパスワード管理を省略できる。

### 3. ネイティブ拡張のビルド依存の隔離

ミドルウェアのサーバープロセスだけでなく、クライアントライブラリもホスト汚染の要因となる。

| gem | 必要なホスト依存 |
|-----|----------------|
| `mysql2` | `libmysqlclient-dev` |
| `pg` | `libpq-dev` |
| `nokogiri` | `libxml2-dev`, `libxslt1-dev` |
| `image_processing` | `libvips-dev` |
| `sqlite3` | `libsqlite3-dev` |

これを解決するには、Railsアプリの実行自体もコンテナ内で行う必要がある。開発用Dockerfileにすべてのビルド依存を含め、gemはnamed volumeに格納する。

```dockerfile
# .dockerdev/Dockerfile
ARG RUBY_VERSION=3.4.2
FROM ruby:${RUBY_VERSION}-slim

ARG UID=1000
ARG GID=1000

RUN apt-get update -qq && \
    apt-get install -yq --no-install-recommends \
      build-essential git curl \
      libpq-dev \
      default-libmysqlclient-dev \
      libxml2-dev libxslt1-dev \
      libvips-dev \
      libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -g "${GID}" devuser \
    && useradd --create-home -u "${UID}" -g "${GID}" devuser

ENV BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3

WORKDIR /app
USER devuser
```

#### ボリューム設計

| パス | マウント種別 | 理由 |
|------|-------------|------|
| `/app`（ソースコード） | bind mount | ホスト編集が即座に反映 |
| `/usr/local/bundle` | named volume | ネイティブ拡張がホストに漏れない |
| `/app/node_modules` | named volume | Linuxバイナリがホストと競合しない |
| `/app/tmp/pids` | tmpfs | stale PID防止 |

bind mountでソースを共有しつつ、ビルド成果物はnamed volumeに閉じ込めることで、ホストには一切の依存が漏れない。

### 4. システムテストのコンテナ実行

`selenium/standalone-chromium`イメージを使用し、ホストにChrome/Chromiumをインストールせずにシステムテストを実行できる。

```yaml
services:
  chrome:
    image: selenium/standalone-chromium:latest
    ports:
      - "127.0.0.1:4444:4444"
      - "127.0.0.1:7900:7900"  # noVNC（目視デバッグ用）
    extra_hosts:
      - "host.docker.internal:host-gateway"  # Linux必須
    volumes:
      - /dev/shm:/dev/shm  # Chrome OOM防止
```

Capybaraの設定で、環境変数`SELENIUM_REMOTE_URL`の有無によりローカル実行とリモート実行を切り替える。

```ruby
if ENV["SELENIUM_REMOTE_URL"]
  driven_by :selenium, using: :headless_chrome,
    options: { browser: :remote, url: ENV["SELENIUM_REMOTE_URL"] }
  Capybara.server_host = "0.0.0.0"
  Capybara.server_port = 3001
  Capybara.app_host = "http://host.docker.internal:3001"
else
  driven_by :selenium, using: :headless_chrome
end
```

注意点として、Railsテストサーバーは`0.0.0.0`でリッスンする必要がある（コンテナ内のChromiumからアクセスするため）。Linuxでは`host.docker.internal`は自動で解決されないため、`extra_hosts`設定が必須となる。

### 5. UID/GIDマッピング

bind mountではUID番号がそのままホスト・コンテナ間で共有される。コンテナ内プロセスが作成したファイルの所有者は、ホスト側ではそのUID番号のユーザーとなる。

#### Docker の挙動

| コンテナ内UID | ホスト側所有者 | 問題 |
|---|---|---|
| 0 (root) | root | ホストユーザーが編集・削除できない |
| 1000（`--user`指定） | UID 1000（ホストユーザー） | 問題なし |

Dockerの場合、`--user "$(id -u):$(id -g)"` またはDockerfile内で`ARG UID/GID`パターンを使い、ホストユーザーと同じUIDのユーザーをコンテナ内に作成する。

```yaml
# compose.yml
services:
  rails:
    build:
      args:
        UID: ${UID:-1000}
        GID: ${GID:-1000}
    user: "${UID:-1000}:${GID:-1000}"
```

制約として、UIDがイメージにベイクされるため、UIDが異なる開発者はリビルドが必要。

#### Podman rootless の挙動

Podmanはユーザー名前空間（user namespace）を使用する。デフォルトではコンテナ内root（UID 0）がホストの実行ユーザーにマッピングされる。

| モード | コンテナUID 0 → ホスト | コンテナUID 1000 → ホスト |
|---|---|---|
| デフォルト | UID 1000（自分） | UID 101000（subordinate） |
| `--userns=keep-id` | UID 100000（subordinate） | UID 1000（自分） |

`--userns=keep-id`を使うと、ホストユーザーのUIDがコンテナ内でも同じUIDとして見える。

```yaml
# compose.yml (Podman)
services:
  rails:
    userns: keep-id
```

Docker（ARG UID パターン）と比較して、Podmanの`keep-id`はビルド時にUIDを固定する必要がなく、異なるUIDの開発者間でイメージを共有できる利点がある。

#### 注意事項

- Podman rootlessの`keep-id`とnamed volumeの組み合わせでは、ファイル所有者が意図しないUIDになる既知の問題がある
- Docker Desktop（macOS/Windows）ではVM経由のファイル共有層がUID変換を行うため、この問題はほぼ発生しない
- Docker Desktop for Linuxでもvirtiofsdによるマッピングが行われ、素のDocker Engineとは異なる挙動を示す

### 6. Docker vs Podman 比較

| 項目 | Docker | Podman |
|------|--------|--------|
| デーモン | dockerd常駐（root） | デーモンレス |
| デフォルト権限 | rootful | **rootless** |
| UID解決方法 | `ARG UID` + `--user` | `--userns=keep-id` |
| Compose互換 | ネイティブ | `podman-compose`で互換 |
| ホストアクセス名 | `host.docker.internal` | `host.containers.internal` |
| named volume + UID | 問題なし | `keep-id`との組合せに既知問題 |
| コンテナ起動速度 | 標準 | デーモンレスのため高速 |
| エコシステム | 広い | Docker互換で概ね利用可能 |

### 7. AIエージェントとの連携

Claude Codeのサンドボックス機能（bubblewrap）と、コンテナ実行を組み合わせた多層防御が可能。

| レイヤー | 手段 | 防御範囲 |
|----------|------|----------|
| L1 | Claude Codeネイティブサンドボックス | ファイルシステム・ネットワーク制限 |
| L2 | テスト・サーバー実行をコンテナ内で実施 | ホストプロセスからの隔離 |
| L3 | Podman rootless | 特権昇格の防止 |

Claude Codeはホストでソースコードの読み書きを直接行い、`docker compose exec`でコマンド実行をコンテナに委譲する構成となる。hooks機能やシェルラッパーにより透過的な連携が可能。

### 8. DXツール: dip

Evil Martians製の[dip](https://github.com/bibendi/dip)は`docker compose run/exec`をラップし、ネイティブ開発に近いコマンド体験を提供する。

```yaml
# dip.yml
version: '7.1'
compose:
  files: [.dockerdev/compose.yml]

interaction:
  rails:
    service: rails
    command: bundle exec rails
    subcommands:
      s:
        service: web
        compose:
          run_options: [service-ports]
  rspec:
    service: rails
    command: bundle exec rspec
    environment:
      RAILS_ENV: test
  bundle:
    service: rails
    command: bundle
```

使用例:

```bash
dip rails server     # docker compose exec ... bundle exec rails server
dip rspec            # docker compose run --rm ... bundle exec rspec
dip rails db:migrate # docker compose exec ... bundle exec rails db:migrate
```

dipを使わない場合でも、シェルエイリアスで同等の体験は実現可能。

```bash
alias dce='docker compose -f .dockerdev/compose.yml exec rails'
alias dcr='docker compose -f .dockerdev/compose.yml run --rm rails'
```

### 9. ファイル監視とホットリロード

| 環境 | inotify伝搬 | Rails auto-reload | tailwindcss:watch |
|------|------------|-------------------|-------------------|
| Linux（bind mount） | ネイティブ | 問題なし | 問題なし |
| macOS Docker Desktop（VirtioFS） | VM経由で若干の遅延 | 実用上問題なし | `tty: true`推奨 |

Linuxではbind mountがネイティブであり、ファイル変更イベント（inotify）がそのまま伝搬する。macOSではDocker DesktopのVirtioFSにより実用的な速度で動作するが、named volumeに依存キャッシュを配置することでパフォーマンスを最適化できる。

### 10. VS Code IDE機能（LSP・デバッガ）のコンテナ環境での利用

Dev Containerでは、VS Code自体がコンテナ内で動作するため、Ruby LSPやデバッガの設定が不要だった。「ホスト編集 + コンテナ実行」パターンでは、ホストにRubyがないためこれらのIDE機能が動作しない問題がある。

#### 問題の構造

| 機能 | 依存するもの | Dev Containerでは |
|------|-------------|------------------|
| ruby-lsp / solargraph | Rubyランタイム + gem | コンテナ内で自然に動作 |
| ruby-debug (rdbg) 接続 | デバッグポート | ローカル接続で動作 |

#### アプローチA: VS Code「Attach to Running Container」（推奨）

Dev Containers拡張（`ms-vscode-remote.remote-containers`）には、`devcontainer.json`を必要とせずに任意の起動中コンテナにアタッチする機能がある。

```
Command Palette → "Dev Containers: Attach to Running Container..."
→ docker compose で起動中の rails コンテナを選択
→ 新しい VS Code ウィンドウが開く（コンテナ内で動作）
```

VS Code Serverがコンテナ内にインストールされ、拡張機能（ruby-lsp, rdbg）もコンテナ内で実行される。ターミナルもコンテナ内で動作する。

Dev Containerとの違いは、コンテナのライフサイクルを`docker compose`で自分で管理する点にある。`devcontainer.json`は不要であり、VS Codeがコンテナの起動・停止を管理しない。

| 観点 | Dev Container | Attach to Container |
|------|--------------|-------------------|
| 設定ファイル | `devcontainer.json` 必須 | 不要 |
| コンテナ管理 | VS Codeが管理 | docker composeで自分で管理 |
| 再現性 | 宣言的（バージョン管理可） | 手動（各開発者が設定） |
| Claude Code | コンテナ内（問題あり） | ホストで別ターミナル（問題なし） |

VS Code用の永続設定は `~/.config/Code/User/globalStorage/ms-vscode-remote.remote-containers/imageConfigs/` に保存できる。

```json
{
  "extensions": [
    "Shopify.ruby-lsp",
    "KoichiSasada.vscode-rdbg"
  ],
  "settings": {
    "rubyLsp.rubyVersionManager": {
      "identifier": "none"
    }
  },
  "workspaceFolder": "/app"
}
```

#### アプローチB: ruby-debug のTCPリモート接続（デバッガのみ）

LSPの問題とは独立して、デバッガはTCP接続で解決できる。ホストのVS CodeからコンテナのRailsプロセスにリモートデバッグ接続する。

compose.ymlでデバッグポートを公開する:

```yaml
services:
  web:
    ports:
      - "3000:3000"
      - "12345:12345"  # debug port
    environment:
      RUBY_DEBUG_OPEN: "true"
      RUBY_DEBUG_HOST: "0.0.0.0"
      RUBY_DEBUG_PORT: "12345"
```

VS Codeの`launch.json`でリモート接続を設定する:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "rdbg",
      "name": "Attach to Docker",
      "request": "attach",
      "debugPort": "localhost:12345",
      "localfsMap": "/app:${workspaceFolder}"
    }
  ]
}
```

`localfsMap`がコンテナ内パス(`/app`)とホストパス(`${workspaceFolder}`)を対応付け、ブレークポイントやステップ実行がホストのVS Codeで動作する。VS Code拡張 [VSCode rdbg Ruby Debugger](https://marketplace.visualstudio.com/items?itemName=KoichiSasada.vscode-rdbg) が必要。

このアプローチはLSP問題を解決しないため、単独で使う場合はアプローチCとの併用が必要。

#### アプローチC: ホストにRubyを入れる（ツーリング専用）

mise / asdf でコンテナと同じバージョンのRubyをホストにインストールし、LSP用途に限定して使用する。

```bash
mise use ruby@3.4.2
```

LSPはホストのRubyで動作し、実行・テストはコンテナで行う。ホストには`libpq-dev`等のネイティブ拡張ビルド依存は不要（LSP用gemにはネイティブ拡張が必要なものが少ない）だが、Rubyランタイム自体はホストに入る。

制約として、ホストとコンテナのRubyバージョンやgem構成が乖離するとLSPの解析精度が低下する可能性がある。

#### VS Code Claude Code拡張とコンテナアタッチの関係

VS Code拡張版Claude Codeは、「Attach to Running Container」を使用した場合**コンテナ側で動作する**。つまりClaude Code拡張もコンテナ内で実行され、Dev Containerと同様の問題（[#10379](https://github.com/anthropics/claude-code/issues/10379)）が発生する可能性がある。

このため、コンテナアタッチ環境ではClaude Codeの利用方法に選択肢が生じる。

#### VS Code拡張版 vs CLI版 Claude Code の機能差

| 機能 | VS Code拡張 | CLI |
|------|------------|-----|
| 画像ドラッグ&ドロップ | 対応 | 非対応 |
| 画像ペースト | 対応 | `Ctrl+V`で対応 |
| ファイルパス指定で画像入力 | 対応 | 対応 |
| インラインdiff表示 | 対応 | 非対応 |
| IDE コンテキスト（開いているファイル、選択範囲、診断情報） | 対応 | 非対応 |
| Plan のマークダウン編集 | 対応 | テキストベース |
| `!` bash ショートカット | 非対応 | 対応 |
| タブ補完 | 非対応 | 対応 |

画像入力はCLIでもファイルパス指定や`Ctrl+V`ペーストで可能だが、ドラッグ&ドロップやインラインdiff等のビジュアルな体験はVS Code拡張でのみ利用可能。エラー画面のスクリーンショットを見せるといったユースケースでは、CLIでは画像ファイルとして保存してからパスを指定する手順が必要となり、拡張版に比べてワークフローが冗長になる。

#### 推奨構成の選択肢

**構成A: VS Code拡張版Claude Codeを使う（IDE体験優先）**

```
┌── VS Code ウィンドウ（Attach to Container）────────────┐
│  ruby-lsp          → コンテナ内で動作                    │
│  rdbg デバッガ      → コンテナ内で動作                    │
│  Claude Code 拡張   → コンテナ内で動作（#10379の影響あり）│
│  ターミナル         → コンテナ内                          │
│  ファイル編集       → bind mount 経由                     │
└────────────────────────────────────────────────────────┘
```

利点: 画像ペースト、インラインdiff、IDEコンテキスト等のフル機能が使える。
欠点: Claude Codeがコンテナ内で動作するため、Dev Containerと同じ問題が発生する可能性がある。

**構成B: CLI版Claude Codeをホストで使う（安定性優先）**

```
┌── VS Code ウィンドウ（Attach to Container）────────┐
│  ruby-lsp     → コンテナ内で動作                    │
│  rdbg デバッガ → コンテナ内で動作                    │
│  ターミナル    → コンテナ内                          │
│  ファイル編集  → bind mount 経由                     │
└──────────────────────────────────────────────────┘

┌── ホスト ターミナル ──────────────────────────────┐
│  Claude Code CLI → ホストで動作（#10379の影響なし）│
│  git操作         → ホストで動作                    │
│  docker compose  → ホストから操作                  │
└──────────────────────────────────────────────────┘
```

利点: Claude Codeがホストで安定動作。Dev Container問題を完全に回避。
欠点: 画像入力はファイルパス指定が必要。インラインdiffやIDEコンテキストが使えない。

**構成C: ハイブリッド（VS Code拡張版 + CLI版を併用）**

```
┌── VS Code ウィンドウ（Attach to Container）────────────┐
│  ruby-lsp          → コンテナ内で動作                    │
│  rdbg デバッガ      → コンテナ内で動作                    │
│  Claude Code 拡張   → コンテナ内（画像入力・diff時に使用）│
│  ターミナル         → コンテナ内                          │
│  ファイル編集       → bind mount 経由                     │
└────────────────────────────────────────────────────────┘

┌── ホスト ターミナル ──────────────────────────────┐
│  Claude Code CLI → ホストで動作（主要な開発作業）   │
│  git操作         → ホストで動作                    │
│  docker compose  → ホストから操作                  │
└──────────────────────────────────────────────────┘
```

利点: 用途に応じて使い分け可能。主要な作業はCLIで安定動作、画像やdiffが必要な場面では拡張版を使用。
欠点: 2つのClaude Codeインスタンスの使い分けが必要。同一ファイルへの同時編集に注意が必要。

どの構成が最適かは#10379の問題の深刻度に依存する。問題が軽微であれば構成A、深刻であれば構成B、場面に応じた使い分けが可能であれば構成Cが適切。

#### ruby-lspのリモートLSP非対応について

ruby-lsp（Shopify製）は stdio ベースの通信のみをサポートしており、TCPソケット経由のリモート接続には対応していない（[ruby-lsp#480](https://github.com/Shopify/ruby-lsp/issues/480)）。そのため、ホストのVS Codeからコンテナ内のruby-lspにネットワーク経由で接続することはできない。solargraphはTCPソケットモード（`solargraph socket --host 0.0.0.0 --port 7658`）をサポートしているが、ruby-lspが主流となっている現状ではアプローチAの「Attach to Container」が最も現実的な解決策となる。

## 分析・考察

### 主要な発見

1. **「ミドルウェアだけコンテナ化」では不十分**。ネイティブ拡張を持つgemのビルド依存（`libpq-dev`等）もホスト汚染の原因となるため、Railsアプリの実行自体もコンテナで行う必要がある。

2. **UID/GIDマッピングが最大の技術的課題**。DockerとPodmanで解決方法が異なり、それぞれにトレードオフがある。Dockerは`ARG UID`パターンで対応可能だがチーム内でのUID差異に弱い。Podmanは`--userns=keep-id`で自動対応できるがnamed volumeとの組合せに既知の問題がある。

3. **「ホスト編集 + コンテナ実行」パターンはDev Containerの代替として成立する**。Evil Martians等の実績があり、Claude CodeのようなAIエージェントとの親和性が高い。

4. **Linuxホストが最もシンプル**。bind mountがネイティブであり、inotifyの伝搬やパフォーマンスの問題が発生しない。

5. **VS CodeのIDE機能（LSP・デバッガ）は「Attach to Running Container」で解決できる**。`devcontainer.json`不要で任意のコンテナにアタッチし、ruby-lspやrdbgをコンテナ内で実行可能。ruby-lspがリモートLSP非対応のため、ホストのVS Codeからネットワーク越しにLSPを接続するアプローチは現時点で非現実的である。

6. **VS Code「Attach to Container」使用時、Claude Code拡張もコンテナ内で動作する**。これはDev Containerと同じ問題（#10379）を引き起こす可能性がある。Claude CodeをホストCLIで使用すると問題を回避できるが、画像ドラッグ&ドロップやインラインdiff等のVS Code拡張固有機能が失われるトレードオフがある。CLI版でも画像はファイルパス指定や`Ctrl+V`ペーストで入力可能だが、ワークフローは冗長になる。

### リスクと制約

| リスク | 影響 | 緩和策 |
|--------|------|--------|
| `docker compose exec`の入力がDev Containerより冗長 | DX低下 | dip / シェルエイリアス |
| named volume内gemのデバッグ困難 | 調査効率低下 | `docker compose exec rails bash`で直接確認 |
| Podman `keep-id` + named volumeのUID問題 | ファイル所有者の不整合 | Docker使用、または`:U`オプション |
| macOSでのbind mountパフォーマンス | 開発速度低下 | VirtioFS + named volumeでキャッシュ最適化 |
| VS Code Attach to Containerの再現性 | 開発者ごとに手動設定が必要 | imageConfigs による永続設定、またはREADMEでの手順共有 |
| VS CodeとClaude Codeが異なる環境で動作 | 編集競合の可能性 | bind mountにより即座に反映されるため実用上は問題なし |

## 結論・推奨事項

### 結論

「ホスト編集 + コンテナ実行」パターンは、Dev Containerの代替として実用的である。ソースコードの編集とAIエージェントはホストで動作させ、Rails実行・ミドルウェアはすべてコンテナに閉じ込めることで、ホスト汚染の防止とAIエージェントの利便性を両立できる。

UID/GIDマッピングは最大の注意点であり、DockerとPodmanで異なるアプローチが必要となる。現時点ではDockerの`ARG UID`パターンがnamed volumeとの互換性の点で安定している。

### 推奨事項

1. **段階的に移行する**
   - まず現プロジェクト（spotlight-rails、SQLite3のみ）でDev Container廃止 + ホストローカル開発に移行する
   - ミドルウェア追加時に`.dockerdev/`構成を導入する
   - システムテスト追加時にSeleniumコンテナを追加する

2. **Dockerをベースとする**（当面）
   - 理由: named volumeとの互換性が安定しており、エコシステムが広い
   - Podmanは`keep-id` + named volumeの問題が解消された段階で再評価する

3. **dipの導入を検討する**
   - 理由: `docker compose exec/run`の冗長さを解消し、ネイティブ開発に近いDXを提供する

4. **Claude Codeとの連携設計を行う**
   - hooks機能やラッパースクリプトにより、`bin/rails test`等のコマンドを透過的にコンテナ内で実行する仕組みを構築する

### 次のアクション

- [ ] spotlight-railsでの`.dockerdev/`構成のPoC実装
- [ ] Claude Codeからのコンテナ内コマンド実行の検証
- [ ] UID/GIDマッピングの実機検証（Docker, Podman両方）
- [ ] dipの導入評価
- [ ] VS Code「Attach to Running Container」の動作検証

## 参考資料

- [Ruby on Whales: Dockerizing Ruby and Rails development (Evil Martians)](https://evilmartians.com/chronicles/ruby-on-whales-docker-for-ruby-rails-development)
- [Reusable development containers with Docker Compose and Dip (Evil Martians)](https://evilmartians.com/chronicles/reusable-development-containers-with-docker-compose-and-dip)
- [bibendi/dip - GitHub](https://github.com/bibendi/dip)
- [Docker and the host filesystem owner matching problem (Fullstaq)](https://www.fullstaq.com/knowledge-hub/blogs/docker-and-the-host-filesystem-owner-matching-problem)
- [Understanding rootless Podman's user namespace modes (Red Hat)](https://www.redhat.com/en/blog/rootless-podman-user-namespace-modes)
- [Using volumes with rootless podman (Tutorial Works)](https://www.tutorialworks.com/podman-rootless-volumes/)
- [Claude Code Sandboxing (Anthropic Engineering)](https://www.anthropic.com/engineering/claude-code-sandboxing)
- [Docker Sandboxes for Coding Agents (Docker Blog)](https://www.docker.com/blog/docker-sandboxes-run-claude-code-and-other-coding-agents-unsupervised-but-safely/)
- [claude-code#10379 - Dev Containers issue](https://github.com/anthropics/claude-code/issues/10379)
- [System of a Test: End-to-End Rails Testing (Evil Martians)](https://evilmartians.com/chronicles/system-of-a-test-setting-up-end-to-end-rails-testing)
- [ruby-lsp#480 - Docker/VM host setup (Shopify)](https://github.com/Shopify/ruby-lsp/issues/480)
- [VS Code: Attach to a running container](https://code.visualstudio.com/docs/devcontainers/attach-container)
- [VSCode rdbg Ruby Debugger](https://marketplace.visualstudio.com/items?itemName=KoichiSasada.vscode-rdbg)
- [ruby/debug - Remote debugging over TCP](https://github.com/ruby/debug)
