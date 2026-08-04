# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::AdrManagementHelper, type: :helper do
  describe "#render_adr_markdown" do
    let(:engagement) { create(:adr_management_engagement, code: "spotlight-rails") }
    let!(:adr) { create(:adr_management_adr, engagement: engagement) }

    def adr_link(html)
      Nokogiri::HTML::DocumentFragment.parse(html)
        .css("a[href='#{admin_adr_management_adr_path(adr)}']")
    end

    it "renders markdown" do
      expect(helper.render_adr_markdown("**強調**")).to include("<strong>強調</strong>")
    end

    it "returns an empty string for blank text" do
      expect(helper.render_adr_markdown(nil)).to eq("")
    end

    it "links resolvable adr display numbers" do
      html = helper.render_adr_markdown("#{adr.display_number} の決定を前提とする")

      link = adr_link(html).sole
      expect(link.text).to eq(adr.display_number)
    end

    it "does not link unresolvable tokens" do
      html = helper.render_adr_markdown("UTF-8 と SPOTLIGHT-RAILS-9999 はリンクしない")

      expect(html).to include("UTF-8", "SPOTLIGHT-RAILS-9999")
      expect(Nokogiri::HTML::DocumentFragment.parse(html).css("a")).to be_empty
    end

    it "does not link display numbers inside code blocks" do
      html = helper.render_adr_markdown("```\n#{adr.display_number}\n```")

      expect(adr_link(html)).to be_empty
      expect(html).to include(adr.display_number)
    end

    it "does not link display numbers inside inline code" do
      html = helper.render_adr_markdown("`#{adr.display_number}` を参照")

      expect(adr_link(html)).to be_empty
    end

    it "does not rewrite display numbers inside existing links" do
      html = helper.render_adr_markdown("[#{adr.display_number}](https://example.com/)")

      links = Nokogiri::HTML::DocumentFragment.parse(html).css("a")
      expect(links.sole["href"]).to eq("https://example.com/")
    end

    it "keeps surrounding text escaped" do
      html = helper.render_adr_markdown("<b>タグ</b> と #{adr.display_number}")

      expect(html).not_to include("<b>")
      expect(adr_link(html).size).to eq(1)
    end
  end
end
