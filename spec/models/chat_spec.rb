require "rails_helper"

RSpec.describe Chat, type: :model do
  describe "#assign_title_from" do
    it "空のタイトルに発言の先頭を設定する" do
      chat = create(:chat)

      chat.assign_title_from("昨日の登壇を登録してください。イベントは Fukuoka.rb です。")

      expect(chat.reload.title).to eq("昨日の登壇を登録してください。イベントは Fukuoka.rb です。")
    end

    it "50文字を超える発言は切り詰める" do
      chat = create(:chat)

      chat.assign_title_from("あ" * 100)

      expect(chat.reload.title.length).to eq(50)
    end

    it "タイトルが設定済みの場合は上書きしない" do
      chat = create(:chat, title: "既存タイトル")

      chat.assign_title_from("新しい発言")

      expect(chat.reload.title).to eq("既存タイトル")
    end

    it "空白のみの発言では設定しない" do
      chat = create(:chat)

      chat.assign_title_from("   \n")

      expect(chat.reload.title).to be_nil
    end
  end
end
