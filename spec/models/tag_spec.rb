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

    it "validates presence of bg_color" do
      tag = build(:tag)
      tag.bg_color = nil
      tag.valid?
      expect(tag).not_to be_valid
      expect(tag.errors[:bg_color]).to include("can't be blank")
    end

    it "validates presence of text_color" do
      tag = build(:tag)
      tag.text_color = nil
      tag.valid?
      expect(tag).not_to be_valid
      expect(tag.errors[:text_color]).to include("can't be blank")
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

    describe "#set_random_colors" do
      it "sets random colors when creating a new tag" do
        tag = build(:tag, name: "New Tag", bg_color: nil, text_color: nil)
        tag.valid?

        expect(tag.bg_color).to be_present
        expect(tag.text_color).to be_present
        expect(tag.bg_color).to match(/\A\w+-\d+\z/) # Format: "color-intensity"
        expect(tag.text_color).to match(/\A\w+-\d+\z/) # Format: "color-intensity"
      end

      it "does not override existing colors" do
        tag = build(:tag, name: "Existing Colors", bg_color: "purple-600", text_color: "purple-100")
        tag.valid?

        expect(tag.bg_color).to eq("purple-600")
        expect(tag.text_color).to eq("purple-100")
      end

      it "only sets colors on create, not update" do
        tag = create(:tag, name: "Test Tag")
        original_bg_color = tag.bg_color
        original_text_color = tag.text_color

        tag.update(name: "Updated Name")

        expect(tag.bg_color).to eq(original_bg_color)
        expect(tag.text_color).to eq(original_text_color)
      end
    end
  end

  describe "color generation" do
    describe "#generate_random_color_pair" do
      let(:tag) { Tag.new }

      it "generates colors with proper contrast for dark backgrounds" do
        # Test multiple times to check different combinations
        10.times do
          colors = tag.send(:generate_random_color_pair)
          bg_intensity = colors[:bg_color].split('-').last.to_i
          text_intensity = colors[:text_color].split('-').last.to_i

          if bg_intensity >= 600
            expect(text_intensity).to be <= 200,
              "Dark background (#{colors[:bg_color]}) should have light text, got #{colors[:text_color]}"
          end
        end
      end

      it "generates colors with proper contrast for light backgrounds" do
        # Test multiple times to check different combinations
        10.times do
          colors = tag.send(:generate_random_color_pair)
          bg_intensity = colors[:bg_color].split('-').last.to_i
          text_intensity = colors[:text_color].split('-').last.to_i

          if bg_intensity <= 400
            expect(text_intensity).to be >= 700,
              "Light background (#{colors[:bg_color]}) should have dark text, got #{colors[:text_color]}"
          end
        end
      end

      it "uses valid Tailwind color families" do
        expected_families = %w[red orange amber yellow lime green emerald teal cyan sky blue indigo violet purple fuchsia pink rose]

        colors = tag.send(:generate_random_color_pair)
        bg_family = colors[:bg_color].split('-').first
        text_family = colors[:text_color].split('-').first

        expect(expected_families).to include(bg_family)
        expect(expected_families).to include(text_family)
      end

      it "uses the same color family for background and text" do
        colors = tag.send(:generate_random_color_pair)
        bg_family = colors[:bg_color].split('-').first
        text_family = colors[:text_color].split('-').first

        expect(bg_family).to eq(text_family)
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
    it "returns Tailwind classes based on bg_color and text_color" do
      tag = create(:tag, bg_color: "purple-600", text_color: "purple-100")

      expect(tag.badge_colors).to eq({
        bg_color: "bg-purple-600",
        text_color: "text-purple-100"
      })
    end

    it "works with different color combinations" do
      tag = create(:tag, bg_color: "emerald-200", text_color: "emerald-800")

      expect(tag.badge_colors).to eq({
        bg_color: "bg-emerald-200",
        text_color: "text-emerald-800"
      })
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
      expect(tag.bg_color).to eq("red-600")
      expect(tag.text_color).to eq("red-100")
      expect(tag.slug).to eq("rails")
    end

    it "creates javascript tag with correct attributes" do
      tag = create(:tag, :javascript)
      expect(tag.name).to eq("JavaScript")
      expect(tag.bg_color).to eq("yellow-500")
      expect(tag.text_color).to eq("yellow-900")
      expect(tag.slug).to eq("javascript")
    end

    it "creates docker tag with correct attributes" do
      tag = create(:tag, :docker)
      expect(tag.name).to eq("Docker")
      expect(tag.bg_color).to eq("purple-600")
      expect(tag.text_color).to eq("purple-100")
      expect(tag.slug).to eq("docker")
    end

    it "creates kamal tag with correct attributes" do
      tag = create(:tag, :kamal)
      expect(tag.name).to eq("Kamal")
      expect(tag.bg_color).to eq("blue-600")
      expect(tag.text_color).to eq("blue-100")
      expect(tag.slug).to eq("kamal")
    end

    it "creates devops tag with correct attributes" do
      tag = create(:tag, :devops)
      expect(tag.name).to eq("DevOps")
      expect(tag.bg_color).to eq("green-600")
      expect(tag.text_color).to eq("green-100")
      expect(tag.slug).to eq("devops")
    end
  end

  describe "integration tests" do
    it "creates a valid tag with random colors" do
      tag = Tag.create(name: "Integration Test")

      expect(tag).to be_persisted
      expect(tag.bg_color).to be_present
      expect(tag.text_color).to be_present
      expect(tag.slug).to eq("integration-test")
    end

    it "ensures color contrast is maintained across multiple creations" do
      tags = 5.times.map { Tag.create(name: "Test #{rand(1000)}") }

      tags.each do |tag|
        bg_intensity = tag.bg_color.split('-').last.to_i
        text_intensity = tag.text_color.split('-').last.to_i

        if bg_intensity >= 600
          expect(text_intensity).to be <= 200,
            "Tag #{tag.name}: Dark background (#{tag.bg_color}) should have light text, got #{tag.text_color}"
        else
          expect(text_intensity).to be >= 700,
            "Tag #{tag.name}: Light background (#{tag.bg_color}) should have dark text, got #{tag.text_color}"
        end
      end
    end
  end
end
