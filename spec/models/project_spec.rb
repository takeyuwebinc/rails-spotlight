require 'rails_helper'

RSpec.describe Project, type: :model do
  describe '.import_from_docs' do
    let(:fixtures_dir) { Rails.root.join('spec', 'fixtures', 'files') }

    it 'imports projects from the specified directory' do
      expect {
        Project.import_from_docs(fixtures_dir)
      }.to change(Project, :count).by(1)

      project = Project.find_by(title: 'Test Project')
      expect(project).to be_present
      expect(project.icon).to eq('fa-flask')
      expect(project.color).to eq('purple-600')
      expect(project.technologies).to eq('Ruby, Rails, RSpec')
      expect(project.description).to include('This is a test project created for testing the import functionality.')
    end

    it 'returns the number of imported projects' do
      count = Project.import_from_docs(fixtures_dir)
      expect(count).to eq(1)
    end

    it 'raises an error when source_dir is not provided' do
      expect {
        Project.import_from_docs
      }.to raise_error(ArgumentError)
    end

    context 'when the project already exists' do
      before do
        Project.create!(
          title: 'Test Project',
          description: 'Old description',
          icon: 'fa-old',
          color: 'red-500',
          technologies: 'Old Tech',
          published_at: 1.day.ago
        )
      end

      it 'updates the existing project' do
        expect {
          Project.import_from_docs(fixtures_dir)
        }.not_to change(Project, :count)

        project = Project.find_by(title: 'Test Project')
        expect(project.icon).to eq('fa-flask')
        expect(project.color).to eq('purple-600')
        expect(project.technologies).to eq('Ruby, Rails, RSpec')
        expect(project.description).to include('This is a test project created for testing the import functionality.')
      end
    end
  end
end
