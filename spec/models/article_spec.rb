require 'rails_helper'

RSpec.describe Article, type: :model do
  describe '.import_from_docs' do
    let(:fixtures_dir) { Rails.root.join('spec', 'fixtures', 'files') }

    it 'imports articles from the specified directory' do
      expect {
        Article.import_from_docs(fixtures_dir)
      }.to change(Article, :count).by(1)

      article = Article.find_by(slug: 'test-article')
      expect(article).to be_present
      expect(article.title).to eq('Test Article')
      expect(article.description).to eq('This is a test article for testing the import functionality.')
      expect(article.published_at.to_date.to_s).to eq('2025-05-03')
      expect(article.content.to_plain_text).to include('This is a test article created for testing the import functionality.')
    end

    it 'returns the number of imported articles' do
      count = Article.import_from_docs(fixtures_dir)
      expect(count).to eq(1)
    end

    it 'raises an error when source_dir is not provided' do
      expect {
        Article.import_from_docs
      }.to raise_error(ArgumentError)
    end

    context 'when the article already exists' do
      before do
        Article.create!(
          title: 'Test Article',
          slug: 'test-article',
          description: 'Old description',
          published_at: '2025-01-01'
        )
      end

      it 'updates the existing article' do
        expect {
          Article.import_from_docs(fixtures_dir)
        }.not_to change(Article, :count)

        article = Article.find_by(slug: 'test-article')
        expect(article.description).to eq('This is a test article for testing the import functionality.')
        expect(article.published_at.to_date.to_s).to eq('2025-05-03')
      end
    end
  end
end
