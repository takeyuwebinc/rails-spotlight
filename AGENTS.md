# AGENTS.md

AI エージェント向けのプロジェクト環境情報。

## 利用可能な CLI ツール

DevContainer には以下の CLI がインストール済みで、ホストの認証情報がマウントされているため追加の認証なしで利用できる。

### sentry-cli

- ホストの `~/.sentryclirc` がマウントされており、認証済み。
- Sentry のイシュー確認、リリース管理、ソースマップアップロード等に利用可能。

```bash
sentry-cli info          # 認証状態の確認
sentry-cli issues list   # イシュー一覧
```

### gh (GitHub CLI)

- ホストの `~/.config/gh` がマウントされており、認証済み。
- PR・Issue の作成/参照、GitHub API の呼び出しに利用可能。

```bash
gh pr list
gh issue list
gh api <endpoint>
```
