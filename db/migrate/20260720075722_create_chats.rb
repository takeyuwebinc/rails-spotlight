class CreateChats < ActiveRecord::Migration[8.1]
  def change
    create_table :chats, comment: "AIエージェントとの会話" do |t|
      t.string :title, comment: "会話タイトル（最初の発言から自動設定。一覧表示用）"
      t.timestamps
    end
  end
end
