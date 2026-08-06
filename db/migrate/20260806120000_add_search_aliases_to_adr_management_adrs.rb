# frozen_string_literal: true

# キーワード検索の表記ゆれ対策として、本文に現れない別表記
# （カタカナ⇄英語）を保持する。NULL は未生成、空文字は生成済みで
# エイリアスなしを表す
class AddSearchAliasesToAdrManagementAdrs < ActiveRecord::Migration[8.1]
  def change
    add_column :adr_management_adrs, :search_aliases, :text
  end
end
