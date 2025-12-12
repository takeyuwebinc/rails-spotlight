# 工数管理 MCP Tool 機能設計書

**機能名**: 工数管理 MCP Tool
**バージョン**: 1.0
**作成日**: 2025年12月12日

## 1. 機能概要

### 1.1 目的

LLM（Claude等）を通じて工数管理データの登録・参照を行うためのMCP Tool群を提供する。

- 自然言語での工数登録を実現
- 会話形式での見込み工数設定を可能に
- LLMによる工数データの参照・集計を支援

### 1.2 主要機能

1. **クライアント管理Tool**: クライアントの一覧取得・検索・作成
2. **案件管理Tool**: 案件の一覧取得・検索・作成
3. **月別見込み工数管理Tool**: 見込み工数の一覧取得・作成
4. **工数実績管理Tool**: 工数実績の一覧取得・作成

### 1.3 処理フロー概要

#### 1.3.1 工数登録フロー

1. ユーザーが自然言語で工数を伝える（例: 「今日ABC案件で2時間開発した」）
2. LLMが案件を特定するためfind_work_hour_projectを呼び出す
3. 案件が見つかればcreate_work_hour_entryで工数を登録
4. 登録結果をユーザーに報告

#### 1.3.2 見込み工数登録フロー

1. ユーザーが見込み工数を伝える（例: 「来月のXYZ案件は40時間の予定」）
2. LLMが案件を特定するためfind_work_hour_projectを呼び出す
3. create_work_hour_estimateで見込み工数を登録
4. 登録結果をユーザーに報告

#### 1.3.3 データ参照フロー

1. ユーザーが照会を依頼（例: 「今月の工数を教えて」）
2. LLMがlist_work_hour_entriesで該当データを取得
3. 集計・整形してユーザーに回答

## 2. Tool仕様

### 2.1 クライアント管理Tool

#### 2.1.1 list_work_hour_clients

クライアント一覧を取得する。

**入力パラメータ**: なし

**出力形式**:
```
Found X client(s):
- [code] [name] (projects: N)
- [code] [name] (projects: N)
```

**処理フロー**:
1. 全クライアントを取得
2. 各クライアントの案件数をカウント
3. 一覧形式で出力

#### 2.1.2 find_work_hour_client

クライアントを検索する。

**入力パラメータ**:
| パラメータ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| query | string | ✅ | 検索キーワード |

**出力形式**:
```
Found client:
- Code: [code]
- Name: [name]
- Projects:
  - [project_code]: [project_name] (status)
```

**処理フロー**:
1. codeの完全一致で検索
2. 見つからなければcodeの部分一致で検索
3. 見つからなければnameの部分一致で検索
4. 紐づく案件一覧を含めて出力

#### 2.1.3 create_work_hour_client

クライアントを作成する。

**入力パラメータ**:
| パラメータ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| code | string | ✅ | クライアントコード |
| name | string | ✅ | クライアント名 |

**出力形式**:
```
Client created successfully:
- Code: [code]
- Name: [name]
```

**処理フロー**:
1. codeの重複チェック
2. クライアントを作成
3. 作成結果を出力

**エラー処理**:
- codeが既に存在する場合: 「Client with code '[code]' already exists」

### 2.2 案件管理Tool

#### 2.2.1 list_work_hour_projects

案件一覧を取得する。

**入力パラメータ**:
| パラメータ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| status | string | - | active / closed / all（デフォルト: active） |
| client_code | string | - | クライアントコードでフィルタ |

**出力形式**:
```
Found X project(s):
- [code]: [name]
  Client: [client_name]
  Status: [status]
  Period: [start_date] - [end_date]
```

**処理フロー**:
1. ステータス条件でフィルタ
2. client_codeが指定されていればクライアントでフィルタ
3. 一覧形式で出力

#### 2.2.2 find_work_hour_project

案件を検索する。

**入力パラメータ**:
| パラメータ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| query | string | ✅ | 検索キーワード |

**出力形式**:
```
Found project:
- Code: [code]
- Name: [name]
- Client: [client_name]
- Color: [color]
- Status: [status]
- Period: [start_date] - [end_date]
- Monthly Estimates (upcoming):
  - [YYYY-MM]: [hours]h
```

**処理フロー**:
1. codeの完全一致で検索
2. 見つからなければcodeの部分一致で検索
3. 見つからなければnameの部分一致で検索
4. 今後3ヶ月分の見込み工数を含めて出力

#### 2.2.3 create_work_hour_project

案件を作成する。

**入力パラメータ**:
| パラメータ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| code | string | ✅ | 案件コード |
| name | string | ✅ | 案件名 |
| client_code | string | - | クライアントコード |
| color | string | - | 表示色（デフォルト: #6366f1） |
| start_date | string | - | 開始日（YYYY-MM-DD） |
| end_date | string | - | 終了日（YYYY-MM-DD） |

**出力形式**:
```
Project created successfully:
- Code: [code]
- Name: [name]
- Client: [client_name]
- Color: [color]
- Status: active
```

**処理フロー**:
1. codeの重複チェック
2. client_codeが指定されていればクライアントを検索
3. 案件を作成（statusはactiveで固定）
4. 作成結果を出力

**エラー処理**:
- codeが既に存在する場合: 「Project with code '[code]' already exists」
- client_codeが存在しない場合: 「Client with code '[client_code]' not found」

### 2.3 月別見込み工数管理Tool

#### 2.3.1 list_work_hour_estimates

見込み工数一覧を取得する。

**入力パラメータ**:
| パラメータ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| project_code | string | - | 案件コードでフィルタ |
| year_month | string | - | 対象月でフィルタ（YYYY-MM） |
| from_month | string | - | 開始月（YYYY-MM） |
| to_month | string | - | 終了月（YYYY-MM） |

**出力形式**:
```
Found X estimate(s):
- [YYYY-MM] [project_code]: [project_name] - [hours]h
- [YYYY-MM] [project_code]: [project_name] - [hours]h

Total for [YYYY-MM]: [total_hours]h
```

**処理フロー**:
1. 条件に基づいてフィルタ
2. 年月・案件でソート
3. 月別の合計を含めて出力

#### 2.3.2 create_work_hour_estimate

見込み工数を作成する。

**入力パラメータ**:
| パラメータ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| project_code | string | ✅ | 案件コード |
| year_month | string | ✅ | 対象月（YYYY-MM） |
| estimated_hours | number | ✅ | 見込み工数（時間） |

**出力形式**:
```
Estimate created successfully:
- Project: [project_name] ([project_code])
- Month: [YYYY-MM]
- Hours: [hours]h
```

**処理フロー**:
1. 案件をcodeで検索
2. 同一案件・同一月のデータ存在チェック
3. 見込み工数を作成
4. 作成結果を出力

**エラー処理**:
- project_codeが存在しない場合: 「Project with code '[project_code]' not found」
- 重複する場合: 「Estimate for [project_code] in [year_month] already exists. Use the admin panel to update.」

### 2.4 工数実績管理Tool

#### 2.4.1 list_work_hour_entries

工数実績一覧を取得する。

**入力パラメータ**:
| パラメータ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| project_code | string | - | 案件コードでフィルタ |
| start_date | string | - | 開始日（YYYY-MM-DD） |
| end_date | string | - | 終了日（YYYY-MM-DD） |
| target_month | string | - | 対象月でフィルタ（YYYY-MM） |

**出力形式**:
```
Found X entries:
- [YYYY-MM-DD] [project_name]: [description] ([hours]h [minutes]m)
- [YYYY-MM-DD] [project_name]: [description] ([hours]h [minutes]m)

Total: [total_hours]h [total_minutes]m
```

**処理フロー**:
1. 条件に基づいてフィルタ
2. 作業日でソート
3. 合計時間を含めて出力

**デフォルト動作**:
- パラメータ未指定時は当月のデータを取得

#### 2.4.2 create_work_hour_entry

工数実績を作成する。

**入力パラメータ**:
| パラメータ | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| project_code | string | - | 案件コード（省略時は「その他」） |
| worked_on | string | ✅ | 作業日（YYYY-MM-DD） |
| target_month | string | - | 対象月（YYYY-MM、省略時は作業日の月） |
| description | string | - | 業務内容 |
| minutes | integer | ✅ | 工数（分） |

**出力形式**:
```
Work entry created successfully:
- Date: [YYYY-MM-DD]
- Project: [project_name]
- Description: [description]
- Time: [hours]h [minutes]m
```

**処理フロー**:
1. project_codeが指定されていれば案件を検索
2. target_monthが未指定ならworked_onの月を設定
3. 工数実績を作成
4. 作成結果を出力

**エラー処理**:
- project_codeが指定されたが存在しない場合: 「Project with code '[project_code]' not found」
- minutesが0以下の場合: 「Minutes must be greater than 0」

## 3. ビジネスルール

### 3.1 操作制限

#### 3.1.1 作成のみ許可

- **目的**: 誤操作によるデータ破損を防止
- **対象**: 全Tool
- **ルール**: Create操作のみ提供。Update/Delete操作は管理画面で実施

#### 3.1.2 重複チェック

- **クライアント**: codeの重複を禁止
- **案件**: codeの重複を禁止
- **見込み工数**: 同一案件・同一月の重複を禁止
- **工数実績**: 重複チェックなし（同日同案件で複数登録可能）

### 3.2 デフォルト値

#### 3.2.1 案件作成時

- **color**: #6366f1（indigo）
- **status**: active

#### 3.2.2 工数実績作成時

- **target_month**: worked_onの月初日
- **project**: 未指定時は「その他」（project_id = null）

### 3.3 検索ロジック

#### 3.3.1 検索優先順位

1. codeの完全一致
2. codeの部分一致（前方一致）
3. nameの部分一致

#### 3.3.2 複数件ヒット時

- 最初にマッチした1件を返却
- 複数候補がある旨を出力に含める

## 4. エラーハンドリング

### 4.1 エラー分類

| エラー種別 | 説明 | 例 |
|-----------|------|-----|
| NotFound | 指定されたリソースが存在しない | 「Project not found」 |
| Duplicate | 既に存在するリソースを作成しようとした | 「Client already exists」 |
| Validation | 入力値が不正 | 「Minutes must be greater than 0」 |
| System | システムエラー | 「Unexpected error occurred」 |

### 4.2 エラーメッセージ形式

```
Error: [エラー種別]
[詳細メッセージ]
```

## 5. 非機能要件

### 5.1 セキュリティ

- MCP Serverはローカル環境でのみ動作
- 認証はMCP Server設定に依存

### 5.2 データ整合性

- 作成操作は即時コミット
- バリデーションエラー時はロールバック

---

**関連資料**:
- [工数管理 MCP Tool 要件定義書](./work_hour_mcp_tools_requirements.md)
- [工数管理機能 要件定義書](./work_hour_management_requirements.md)
- [工数管理機能 設計書](./work_hour_management_design.md)
