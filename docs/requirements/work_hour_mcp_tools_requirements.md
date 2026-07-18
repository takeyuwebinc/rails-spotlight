# 工数管理 MCP Tool 要件定義書

## 1. 機能概要

LLM（Claude等）を通じて工数管理データの登録・参照を行うためのMCP Tool群を提供する。

### 主要な提供価値

- 自然言語での工数登録（「今日ABCシステムで2時間開発した」→ 自動登録）
- 会話形式での見込み工数設定（「来月のXYZ案件は40時間の予定」→ 自動登録）
- LLMによる工数データの参照・集計

### 設計方針

| 操作 | 提供 | 理由 |
|------|------|------|
| 作成（Create） | ✅ | LLMによる自動登録を実現 |
| 参照（Read/List） | ✅ | LLMが既存データを把握して適切な登録を行うため必須 |
| 更新（Update） | ❌ | 誤操作防止。管理画面で実施 |
| 削除（Delete） | ❌ | 誤操作防止。管理画面で実施 |

## 2. 機能要件

### 2.1 クライアント管理Tool

#### list_work_hour_clients

クライアント一覧を取得する。

**入力パラメータ**: なし

**出力項目**:
- id
- code
- name
- projects_count（紐づく案件数）

#### find_work_hour_client

クライアントをcode または name で検索する。

**入力パラメータ**:
| パラメータ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| query | string | ✅ | 検索キーワード（code/nameの部分一致） |

**出力項目**:
- id, code, name
- projects（紐づく案件一覧）

#### create_work_hour_client

新規クライアントを作成する。

**入力パラメータ**:
| パラメータ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| code | string | ✅ | クライアントコード（例: abc-corp） |
| name | string | ✅ | クライアント名（例: ABC商事） |

**出力項目**:
- 作成結果（id, code, name）

**エラー条件**:
- codeが既に存在する場合

### 2.2 案件管理Tool

#### list_work_hour_projects

案件一覧を取得する。

**入力パラメータ**:
| パラメータ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| status | string | - | フィルタ: active / closed / all（デフォルト: active） |
| client_code | string | - | クライアントコードでフィルタ |

**出力項目**:
- id, code, name
- client_name
- color, status
- start_date, end_date

#### find_work_hour_project

案件をcode または name で検索する。

**入力パラメータ**:
| パラメータ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| query | string | ✅ | 検索キーワード（code/nameの部分一致） |

**出力項目**:
- id, code, name
- client（id, code, name）
- color, status, start_date, end_date
- monthly_estimates（今後3ヶ月分）

#### create_work_hour_project

新規案件を作成する。

**入力パラメータ**:
| パラメータ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| code | string | ✅ | 案件コード（例: abc-system） |
| name | string | ✅ | 案件名（例: ABC基幹システム） |
| client_code | string | - | クライアントコード |
| color | string | - | 表示色（デフォルト: #6366f1） |
| start_date | string | - | 開始日（YYYY-MM-DD形式） |
| end_date | string | - | 終了日（YYYY-MM-DD形式） |

**出力項目**:
- 作成結果

**エラー条件**:
- codeが既に存在する場合
- client_codeが存在しない場合

### 2.3 月別見込み工数管理Tool

#### list_work_hour_estimates

月別見込み工数一覧を取得する。

**入力パラメータ**:
| パラメータ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| project_code | string | - | 案件コードでフィルタ |
| year_month | string | - | 対象月でフィルタ（YYYY-MM形式） |
| from_month | string | - | 開始月（YYYY-MM形式） |
| to_month | string | - | 終了月（YYYY-MM形式） |

**出力項目**:
- project_code, project_name
- year_month
- estimated_hours

#### create_work_hour_estimate

月別見込み工数を作成する。

**入力パラメータ**:
| パラメータ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| project_code | string | ✅ | 案件コード |
| year_month | string | ✅ | 対象月（YYYY-MM形式） |
| estimated_hours | number | ✅ | 見込み工数（時間） |

**出力項目**:
- 作成結果

**エラー条件**:
- project_codeが存在しない場合
- 同一案件・同一月のデータが既に存在する場合（更新は管理画面で実施）

### 2.4 工数実績管理Tool

#### list_work_hour_entries

工数実績一覧を取得する。

**入力パラメータ**:
| パラメータ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| project_code | string | - | 案件コードでフィルタ |
| start_date | string | - | 開始日（YYYY-MM-DD形式） |
| end_date | string | - | 終了日（YYYY-MM-DD形式） |
| target_month | string | - | 対象月でフィルタ（YYYY-MM形式） |

**出力項目**:
- id
- worked_on, target_month
- project_code, project_name
- description
- minutes, hours

#### create_work_hour_entry

工数実績を作成する。

**入力パラメータ**:
| パラメータ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| project_code | string | - | 案件コード（省略時は「その他」） |
| worked_on | string | ✅ | 作業日（YYYY-MM-DD形式） |
| target_month | string | - | 対象月（YYYY-MM形式、省略時は作業日の月） |
| description | string | - | 業務内容 |
| minutes | integer | ✅ | 工数（分） |

**出力項目**:
- 作成結果

**エラー条件**:
- project_codeが指定されたが存在しない場合
- minutesが0以下の場合

## 3. 想定ユースケース

### 3.1 工数登録

**ユーザー入力例**:
- 「今日、ABC案件で開発作業を2時間やった」
- 「昨日のミーティング1.5時間を登録して」
- 「12/10にXYZシステムのテストを3時間実施」

**処理フロー**:
1. `find_work_hour_project` で案件を特定
2. `create_work_hour_entry` で工数を登録

### 3.2 見込み工数設定

**ユーザー入力例**:
- 「来月のXYZ案件は40時間の予定」
- 「1月から3月までABC案件は毎月80時間」

**処理フロー**:
1. `find_work_hour_project` で案件を特定
2. `create_work_hour_estimate` で見込み工数を登録

### 3.3 工数確認

**ユーザー入力例**:
- 「今月の工数を教えて」
- 「ABC案件の今月の稼働時間は？」
- 「今週何時間働いた？」

**処理フロー**:
1. `list_work_hour_entries` で工数実績を取得
2. 集計結果を回答

### 3.4 案件確認

**ユーザー入力例**:
- 「アクティブな案件一覧」
- 「ABC商事の案件は？」

**処理フロー**:
1. `list_work_hour_projects` で案件一覧を取得
2. 結果を回答

## 4. 非機能要件

### 4.1 セキュリティ

- MCP Serverへのアクセスはローカル環境からのみ許可
- 認証はMCP Server側の設定に依存

### 4.2 データ整合性

- 作成操作のみ許可し、更新・削除は管理画面で実施
- 重複登録はエラーとして拒否（見込み工数の同一案件・同一月）

### 4.3 エラーハンドリング

- 存在しないコードの参照時は明確なエラーメッセージを返す
- バリデーションエラー時は具体的な原因を返す

## 5. 受け入れ条件

### クライアント管理Tool

- [ ] `list_work_hour_clients` でクライアント一覧を取得できること
- [ ] `find_work_hour_client` でクライアントを検索できること
- [ ] `create_work_hour_client` でクライアントを作成できること
- [ ] 重複するcodeでの作成はエラーになること

### 案件管理Tool

- [ ] `list_work_hour_projects` で案件一覧を取得できること
- [ ] `list_work_hour_projects` でstatus/client_codeでフィルタできること
- [ ] `find_work_hour_project` で案件を検索できること
- [ ] `create_work_hour_project` で案件を作成できること
- [ ] 重複するcodeでの作成はエラーになること

### 月別見込み工数管理Tool

- [ ] `list_work_hour_estimates` で見込み工数一覧を取得できること
- [ ] `list_work_hour_estimates` でproject_code/year_monthでフィルタできること
- [ ] `create_work_hour_estimate` で見込み工数を作成できること
- [ ] 同一案件・同一月での重複作成はエラーになること

### 工数実績管理Tool

- [ ] `list_work_hour_entries` で工数実績一覧を取得できること
- [ ] `list_work_hour_entries` で期間・案件でフィルタできること
- [ ] `create_work_hour_entry` で工数実績を作成できること
- [ ] project_code省略時は「その他」として登録されること
- [ ] target_month省略時はworked_onの月が設定されること

## 6. 用語定義

| 用語 | 説明 |
|------|------|
| MCP | Model Context Protocol。LLMがツールを呼び出すためのプロトコル |
| Tool | LLMから呼び出し可能な機能単位 |
| project_code | 案件を一意に識別するコード |
| client_code | クライアントを一意に識別するコード |

## 7. 関連ドキュメント

- [工数管理機能 要件定義書](work_hour_management_requirements.md)
- [工数管理機能 設計書](work_hour_management_design.md)
