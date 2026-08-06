# frozen_string_literal: true

module AdrManagement
  # ADR 本文中の技術用語について、カタカナ⇄英語の別表記を LLM で生成し
  # 検索エイリアスとして保存する。キーワード検索は LIKE 部分一致のため、
  # 本文が英語表記の用語をカタカナで検索すると 0 件になる。この語彙ギャップを
  # 登録時に前払いで埋める。
  #
  # 保存値は改行区切りのプレーンテキストで、NULL は未生成、空文字は
  # 生成済みでエイリアスなしを表す（バックフィルの再実行判定に使う）。
  # LLM 呼び出しの失敗は既存値を保持したまま縮退する（呼び出し元の
  # 登録・更新には影響しない）。
  class GenerateSearchAliases < ApplicationAction
    # 生成語数の上限。過剰生成はキーワード検索の適合率を下げるため打ち切る
    MAX_ALIASES = 20
    MAX_ALIAS_LENGTH = 50
    REQUEST_TIMEOUT = 60

    def initialize(adr:)
      @adr = adr
    end

    def perform
      return success(nil) if Adr::RETIRED_STATUSES.include?(@adr.status)

      aliases = generate_with_llm
      return success(nil) if aliases.nil?

      # 派生値のため版履歴には記録しない（本文の変更ではない）
      @adr.update_column(:search_aliases, aliases.join("\n"))
      success(@adr)
    end

    private

    # 失敗時は nil を返して縮退する（既存のエイリアスは保持される）
    def generate_with_llm
      # モデルは RubyLLM のモデルレジストリに存在しないため、
      # provider 指定 + assume_model_exists でレジストリ解決を迂回する
      llm = llm_context.chat(
        model: AdrManagement.model_for(:alias_generation),
        provider: :openai, assume_model_exists: true
      )
      parse_aliases(llm.ask(prompt).content)
    rescue StandardError => e
      Rails.error.report(e, context: { adr_id: @adr.id }, source: "adr_management.search_aliases")
      nil
    end

    # バックグラウンド実行のためユーザー対面の応答時間制約はないが、
    # ジョブワーカーの長時間占有を避けるため専用のタイムアウトを設定する
    def llm_context
      RubyLLM.context { |config| config.request_timeout = REQUEST_TIMEOUT }
    end

    def body_text
      Adr::ALIAS_SOURCE_ATTRIBUTES.map { |attribute| @adr.public_send(attribute) }.join("\n")
    end

    def prompt
      <<~PROMPT
        あなたは日本語技術文書の検索補助を担当します。以下の ADR（アーキテクチャ決定記録）の
        本文を読み、本文中の技術用語・製品名・概念語について、本文の表記とは異なる
        「カタカナ表記⇄英語表記」の言い換えを列挙してください。

        用途: この ADR は部分一致のキーワード検索で引かれます。本文が英語表記の用語を
        利用者がカタカナで検索した場合に 0 件にならないよう、検索語の候補を用意します。

        規則:
        - 本文に既に出現する表記は出力しない（本文が payload なら「ペイロード」のみ出力する）
        - 一般的な日本語の言い換えや同義語は出力しない。表記の対応のみを対象とする
        - 検索語として使われうる語に限る。#{MAX_ALIASES} 語以内
        - 該当する語がなければ空配列を返す

        出力は次の JSON のみ:
        {"aliases": ["...", "..."]}

        # 対象 ADR
        #{body_text}
      PROMPT
    end

    def parse_aliases(content)
      json = content.to_s[/\{.*\}/m]
      raise ArgumentError, "LLM 応答に JSON が含まれていません" unless json

      body = body_text.downcase
      Array(JSON.parse(json)["aliases"])
        .filter_map { |value| value.to_s.strip.presence }
        .select { |value| value.length <= MAX_ALIAS_LENGTH }
        .reject { |value| body.include?(value.downcase) }
        .uniq { |value| value.downcase }
        .first(MAX_ALIASES)
    end
  end
end
