class AddLastErrorToChats < ActiveRecord::Migration[8.1]
  def change
    add_column :chats, :last_error, :text,
               comment: "直近の応答生成エラー（表示・再送導線用。成功時にクリア）"
  end
end
