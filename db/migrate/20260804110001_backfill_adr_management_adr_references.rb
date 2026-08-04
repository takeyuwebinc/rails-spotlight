# frozen_string_literal: true

# 既存 ADR の本文から参照を一括抽出して参照テーブルへ同期する。
# 本文は変更しないため検索インデックス（埋め込み）の再構築は行わない
class BackfillAdrManagementAdrReferences < ActiveRecord::Migration[8.1]
  def up
    AdrManagement::Adr.find_each do |adr|
      AdrManagement::SyncAdrReferences.perform(adr: adr)
    end
  end

  def down
    # 参照テーブルはテーブル作成マイグレーションの rollback で破棄されるため何もしない
  end
end
