require 'rails_helper'

RSpec.describe LinkMetadatum, type: :model do
  describe 'validations' do
    it 'validates presence of url' do
      metadatum = LinkMetadatum.new(last_fetched_at: Time.current)
      expect(metadatum.valid?).to be false
      expect(metadatum.errors[:url]).to include("can't be blank")
    end

    it 'validates presence of last_fetched_at' do
      metadatum = LinkMetadatum.new(url: 'https://example.com')
      expect(metadatum.valid?).to be false
      expect(metadatum.errors[:last_fetched_at]).to include("can't be blank")
    end

    describe 'uniqueness validation' do
      it 'validates uniqueness of url' do
        create(:link_metadatum, url: 'https://example.com')
        duplicate = build(:link_metadatum, url: 'https://example.com')
        expect(duplicate.valid?).to be false
        expect(duplicate.errors[:url]).to include("has already been taken")
      end
    end
  end

  describe '#cache_valid?' do
    it 'returns true if last_fetched_at is within 24 hours' do
      metadata = LinkMetadatum.new(last_fetched_at: 23.hours.ago)
      expect(metadata.cache_valid?).to be true
    end

    it 'returns false if last_fetched_at is older than 24 hours' do
      metadata = LinkMetadatum.new(last_fetched_at: 25.hours.ago)
      expect(metadata.cache_valid?).to be false
    end
  end

  describe '#update_cache' do
    let(:metadata) { create(:link_metadatum) }
    let(:new_data) do
      {
        title: 'New Title',
        description: 'New Description',
        domain: 'example.org',
        favicon: 'https://example.org/favicon.ico',
        imageUrl: 'https://example.org/image.jpg'
      }
    end

    it 'updates the metadata with new values' do
      expect {
        metadata.update_cache(new_data)
      }.to change { metadata.title }.to('New Title')
        .and change { metadata.description }.to('New Description')
        .and change { metadata.domain }.to('example.org')
        .and change { metadata.favicon }.to('https://example.org/favicon.ico')
        .and change { metadata.image_url }.to('https://example.org/image.jpg')
        .and change { metadata.last_fetched_at }
    end
  end

  describe '.fetch_metadata' do
    context 'with missing URL' do
      it 'returns an error' do
        result = LinkMetadatum.fetch_metadata(nil)
        expect(result[:error]).to eq("URL parameter is required")
      end
    end

    context 'with valid URL and no cache' do
      before do
        # MetaInspectorのモック
        page = double('MetaInspector')
        allow(page).to receive_messages(
          title: 'Example Title',
          best_description: 'Example description',
          host: 'example.com',
          images: double(
            best: 'https://example.com/image.jpg',
            favicon: 'https://example.com/favicon.ico'
          )
        )
        allow(MetaInspector).to receive(:new).and_return(page)
      end

      it 'fetches metadata and creates cache' do
        expect {
          result = LinkMetadatum.fetch_metadata('https://example.com')
          expect(result[:title]).to eq('Example Title')
          expect(result[:description]).to eq('Example description')
          expect(result[:domain]).to eq('example.com')
        }.to change(LinkMetadatum, :count).by(1)

        # キャッシュが作成されたことを確認
        cache = LinkMetadatum.find_by(url: 'https://example.com')
        expect(cache).to be_present
        expect(cache.title).to eq('Example Title')
      end
    end

    context 'with valid URL and valid cache' do
      let!(:cached_metadata) do
        create(:link_metadatum,
          url: 'https://cached.com',
          title: 'Cached Title',
          description: 'Cached Description',
          last_fetched_at: 1.hour.ago
        )
      end

      it 'returns cached metadata without making external request' do
        # MetaInspectorがモックされていても呼ばれないことを確認
        expect(MetaInspector).not_to receive(:new)

        result = LinkMetadatum.fetch_metadata('https://cached.com')
        expect(result[:title]).to eq('Cached Title')
        expect(result[:description]).to eq('Cached Description')
      end
    end

    context 'with valid URL and expired cache' do
      let!(:expired_metadata) do
        create(:link_metadatum,
          url: 'https://expired.com',
          title: 'Old Title',
          description: 'Old Description',
          last_fetched_at: 25.hours.ago
        )
      end

      before do
        # MetaInspectorのモック
        page = double('MetaInspector')
        allow(page).to receive_messages(
          title: 'New Title',
          best_description: 'New Description',
          host: 'expired.com',
          images: double(
            best: 'https://expired.com/new-image.jpg',
            favicon: 'https://expired.com/new-favicon.ico'
          )
        )
        allow(MetaInspector).to receive(:new).and_return(page)
      end

      it 'fetches fresh metadata and updates cache' do
        result = LinkMetadatum.fetch_metadata('https://expired.com')
        expect(result[:title]).to eq('New Title')

        # キャッシュが更新されたことを確認
        expired_metadata.reload
        expect(expired_metadata.title).to eq('New Title')
        expect(expired_metadata.last_fetched_at).to be > 1.minute.ago
      end
    end

    context 'when metadata fetching fails with expected error' do
      before do
        allow(MetaInspector).to receive(:new).and_raise(MetaInspector::RequestError.new("Failed to fetch metadata"))
      end

      it 'returns specific error information' do
        result = LinkMetadatum.fetch_metadata('https://example.com')
        expect(result[:error]).to eq("Failed to fetch metadata")
      end
    end

    context 'when metadata fetching fails with unexpected error' do
      before do
        allow(MetaInspector).to receive(:new).and_raise(StandardError.new("Unexpected error"))
        allow(Rails.error).to receive(:report)
      end

      it 'reports error and returns generic error message' do
        result = LinkMetadatum.fetch_metadata('https://example.com')

        # エラーが報告されたことを確認
        expect(Rails.error).to have_received(:report).with(
          an_instance_of(StandardError),
          hash_including(context: { url: 'https://example.com' })
        )

        # 一般的なエラーメッセージが返されることを確認
        expect(result[:error]).to eq("メタデータの取得中に問題が発生しました。しばらく経ってからもう一度お試しください。")
      end
    end
  end

  describe '.cache_duration' do
    context 'when config is set' do
      before do
        allow(Rails.application.config).to receive(:respond_to?).with(any_args).and_return(false)
        allow(Rails.application.config).to receive(:respond_to?).with(:link_metadata_cache_duration, any_args).and_return(true)
        allow(Rails.application.config).to receive(:link_metadata_cache_duration).and_return(12.hours)
      end

      it 'returns the configured duration' do
        expect(LinkMetadatum.cache_duration).to eq(12.hours)
      end
    end

    context 'when config is not set' do
      before do
        allow(Rails.application.config).to receive(:respond_to?).with(any_args).and_return(false)
        allow(Rails.application.config).to receive(:respond_to?).with(:link_metadata_cache_duration, any_args).and_return(false)
      end

      it 'returns the default duration (24 hours)' do
        expect(LinkMetadatum.cache_duration).to eq(24.hours)
      end
    end
  end
end
