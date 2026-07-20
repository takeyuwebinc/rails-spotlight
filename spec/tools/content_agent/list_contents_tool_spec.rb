require "rails_helper"

RSpec.describe ContentAgent::ListContentsTool do
  describe "#execute" do
    it "対象種別の一覧を返す" do
      create(:project, title: "Spotlight")
      create(:project, title: "Another")

      result = described_class.new.execute(target_type: "Project")

      expect(result[:items].size).to eq(2)
      expect(result[:items].first).to include(:id, :title, :published_at)
    end

    it "キーワードで部分一致に絞り込む" do
      create(:project, title: "Spotlight")
      create(:project, title: "Another")

      result = described_class.new.execute(target_type: "Project", keyword: "Spot")

      expect(result[:items].map { |item| item[:title] }).to eq([ "Spotlight" ])
    end

    it "不正な対象種別はエラーを返す" do
      result = described_class.new.execute(target_type: "AdrManagement::Adr")

      expect(result[:error]).to be_present
    end
  end
end

RSpec.describe ContentAgent::GetContentTool do
  describe "#execute" do
    it "全属性とタグを返す" do
      engagement = SpeakingEngagement.create!(
        title: "t", slug: "s1", event_name: "e", event_date: "2026-07-01"
      )
      engagement.tags << Tag.create!(name: "Ruby")

      result = described_class.new.execute(target_type: "SpeakingEngagement", id: engagement.id)

      expect(result["title"]).to eq("t")
      expect(result["tags"]).to eq([ "Ruby" ])
    end

    it "存在しないレコードはエラーを返す" do
      result = described_class.new.execute(target_type: "Project", id: 999_999)

      expect(result[:error]).to include("見つかりません")
    end
  end
end
