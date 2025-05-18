require "rails_helper"

RSpec.describe ImagePathResolver do
  describe "#call" do
    it "returns the original path for URLs" do
      resolver = ImagePathResolver.new("https://example.com/image.jpg")
      expect(resolver.call).to eq("https://example.com/image.jpg")
    end

    it "returns the original path for absolute paths" do
      resolver = ImagePathResolver.new("/images/photo.jpg")
      expect(resolver.call).to eq("/images/photo.jpg")
    end

    it "converts relative paths to image paths" do
      resolver = ImagePathResolver.new("logo.png")
      # ApplicationController.helpers.image_pathの結果をモック
      allow(ApplicationController.helpers).to receive(:image_path).with("logo.png").and_return("/assets/logo-a1b2c3d4e5f6.png")
      expect(resolver.call).to eq("/assets/logo-a1b2c3d4e5f6.png")
    end
  end
end
