require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#page_title' do
    it 'returns base title when no title is provided' do
      expect(helper.page_title).to eq('TakeyuWeb')
    end

    it 'returns combined title when title is provided' do
      expect(helper.page_title('Test Article')).to eq('Test Article | TakeyuWeb')
    end

    it 'returns base title when empty string is provided' do
      expect(helper.page_title('')).to eq('TakeyuWeb')
    end
  end

  describe '#page_description' do
    it 'returns default description when no description is provided' do
      default_description = '技術ブログ - Rails、JavaScript、Web開発に関する記事を発信しています'
      expect(helper.page_description).to eq(default_description)
    end

    it 'returns provided description when description is given' do
      custom_description = 'Custom description for this page'
      expect(helper.page_description(custom_description)).to eq(custom_description)
    end

    it 'returns default description when empty string is provided' do
      default_description = '技術ブログ - Rails、JavaScript、Web開発に関する記事を発信しています'
      expect(helper.page_description('')).to eq(default_description)
    end
  end

  describe '#canonical_url' do
    before do
      allow(helper.request).to receive(:original_url).and_return('https://example.com/current-page')
    end

    it 'returns current URL when no URL is provided' do
      expect(helper.canonical_url).to eq('https://example.com/current-page')
    end

    it 'returns provided URL when URL is given' do
      custom_url = 'https://example.com/custom-page'
      expect(helper.canonical_url(custom_url)).to eq(custom_url)
    end
  end

  describe '#og_image_url' do
    it 'returns default logo URL when no image is provided' do
      allow(helper).to receive(:asset_url).with('logo.png').and_return('https://example.com/logo.png')
      expect(helper.og_image_url).to eq('https://example.com/logo.png')
    end

    it 'returns custom image URL when image path is provided' do
      allow(helper).to receive(:asset_url).with('logo.png').and_return('https://example.com/logo.png')
      allow(helper).to receive(:asset_url).with('custom.jpg').and_return('https://example.com/custom.jpg')
      expect(helper.og_image_url('custom.jpg')).to eq('https://example.com/custom.jpg')
    end
  end
end
