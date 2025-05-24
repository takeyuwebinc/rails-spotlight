require 'rails_helper'

RSpec.describe Tag, type: :model do
  describe "associations" do
    it "has many article_tags" do
      tag = create(:tag)
      expect(tag.article_tags).to be_empty
      expect(tag).to respond_to(:article_tags)
    end

    it "has many articles through article_tags" do
      tag = create(:tag)
      expect(tag.articles).to be_empty
      expect(tag).to respond_to(:articles)
    end

    it "destroys dependent article_tags when destroyed" do
      tag = create(:tag)
      article = create(:article)
      tag.articles << article

      expect { tag.destroy }.to change { ArticleTag.count }.by(-1)
    end
  end

  describe "validations" do
    it "validates presence of name" do
      tag = build(:tag, name: nil)
      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include("can't be blank")
    end

    it "validates uniqueness of name" do
      create(:tag, name: "Rails")
      tag = build(:tag, name: "Rails")
      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include("has already been taken")
    end

    it "validates presence of slug after generation" do
      # Since slug is auto-generated from name, we need to test with blank name
      tag = build(:tag, name: "", slug: nil)
      expect(tag).not_to be_valid
      expect(tag.errors[:slug]).to include("can't be blank")
    end

    it "validates uniqueness of slug" do
      create(:tag, name: "Rails") # This will create slug "rails"
      tag = build(:tag, name: "Rails") # This will also try to create slug "rails"
      expect(tag).not_to be_valid
      expect(tag.errors[:slug]).to include("has already been taken")
    end

    it "validates presence of color" do
      tag = build(:tag, color: nil)
      expect(tag).not_to be_valid
      expect(tag.errors[:color]).to include("can't be blank")
    end
  end

  describe "callbacks" do
    describe "#generate_slug" do
      it "generates slug from name before validation" do
        tag = build(:tag, name: "Ruby on Rails", slug: nil)
        tag.valid?
        expect(tag.slug).to eq("ruby-on-rails")
      end

      it "handles special characters in name" do
        tag = build(:tag, name: "C++ Programming", slug: nil)
        tag.valid?
        expect(tag.slug).to eq("c-programming")
      end

      it "does not override existing slug" do
        tag = build(:tag, name: "Custom Name", slug: "custom-slug")
        tag.valid?
        expect(tag.slug).to eq("custom-slug")
      end
    end
  end

  describe "scopes" do
    describe ".ordered" do
      let!(:tag_z) { create(:tag, name: "Z Tag") }
      let!(:tag_a) { create(:tag, name: "A Tag") }
      let!(:tag_m) { create(:tag, name: "M Tag") }

      it "orders tags by name" do
        expect(Tag.ordered).to eq([ tag_a, tag_m, tag_z ])
      end
    end
  end

  describe "#to_param" do
    it "returns the slug" do
      tag = create(:tag, name: "Ruby on Rails")
      expect(tag.to_param).to eq("ruby-on-rails")
    end
  end

  describe "#badge_colors" do
    context "with red color" do
      let(:tag) { create(:tag, color: "red") }

      it "returns red color scheme" do
        expect(tag.badge_colors).to eq({
          bg_color: "bg-red-100",
          text_color: "text-red-800"
        })
      end
    end

    context "with blue color" do
      let(:tag) { create(:tag, color: "blue") }

      it "returns blue color scheme" do
        expect(tag.badge_colors).to eq({
          bg_color: "bg-blue-100",
          text_color: "text-blue-800"
        })
      end
    end

    context "with green color" do
      let(:tag) { create(:tag, color: "green") }

      it "returns green color scheme" do
        expect(tag.badge_colors).to eq({
          bg_color: "bg-green-100",
          text_color: "text-green-800"
        })
      end
    end

    context "with yellow color" do
      let(:tag) { create(:tag, color: "yellow") }

      it "returns yellow color scheme" do
        expect(tag.badge_colors).to eq({
          bg_color: "bg-yellow-100",
          text_color: "text-yellow-800"
        })
      end
    end

    context "with purple color" do
      let(:tag) { create(:tag, color: "purple") }

      it "returns purple color scheme" do
        expect(tag.badge_colors).to eq({
          bg_color: "bg-purple-100",
          text_color: "text-purple-800"
        })
      end
    end

    context "with orange color" do
      let(:tag) { create(:tag, color: "orange") }

      it "returns orange color scheme" do
        expect(tag.badge_colors).to eq({
          bg_color: "bg-orange-100",
          text_color: "text-orange-800"
        })
      end
    end

    context "with pink color" do
      let(:tag) { create(:tag, color: "pink") }

      it "returns pink color scheme" do
        expect(tag.badge_colors).to eq({
          bg_color: "bg-pink-100",
          text_color: "text-pink-800"
        })
      end
    end

    context "with indigo color" do
      let(:tag) { create(:tag, color: "indigo") }

      it "returns indigo color scheme" do
        expect(tag.badge_colors).to eq({
          bg_color: "bg-indigo-100",
          text_color: "text-indigo-800"
        })
      end
    end

    context "with unknown color" do
      let(:tag) { create(:tag, color: "unknown") }

      it "returns gray color scheme as default" do
        expect(tag.badge_colors).to eq({
          bg_color: "bg-gray-100",
          text_color: "text-gray-800"
        })
      end
    end
  end

  describe "SEO methods" do
    let(:tag) { create(:tag, name: "Ruby on Rails") }

    describe "#description" do
      it "returns SEO-friendly description" do
        expected = "Articles and insights about Ruby on Rails. Explore technical content, tutorials, and best practices related to Ruby on Rails."
        expect(tag.description).to eq(expected)
      end
    end

    describe "#page_title" do
      it "returns page title for SEO" do
        expect(tag.page_title).to eq("Ruby on Rails Articles")
      end
    end

    describe "#english_title" do
      it "returns English title for display" do
        expect(tag.english_title).to eq("Exploring Ruby on Rails")
      end
    end
  end

  describe "factory traits" do
    it "creates rails tag with correct attributes" do
      tag = create(:tag, :rails)
      expect(tag.name).to eq("Rails")
      expect(tag.color).to eq("red")
      expect(tag.slug).to eq("rails")
    end

    it "creates javascript tag with correct attributes" do
      tag = create(:tag, :javascript)
      expect(tag.name).to eq("JavaScript")
      expect(tag.color).to eq("yellow")
      expect(tag.slug).to eq("javascript")
    end

    it "creates docker tag with correct attributes" do
      tag = create(:tag, :docker)
      expect(tag.name).to eq("Docker")
      expect(tag.color).to eq("purple")
      expect(tag.slug).to eq("docker")
    end

    it "creates kamal tag with correct attributes" do
      tag = create(:tag, :kamal)
      expect(tag.name).to eq("Kamal")
      expect(tag.color).to eq("blue")
      expect(tag.slug).to eq("kamal")
    end

    it "creates devops tag with correct attributes" do
      tag = create(:tag, :devops)
      expect(tag.name).to eq("DevOps")
      expect(tag.color).to eq("green")
      expect(tag.slug).to eq("devops")
    end
  end
end
