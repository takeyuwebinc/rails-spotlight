require 'rails_helper'
require 'rake'

RSpec.describe 'db:import task' do
  before do
    # Load the Rails application tasks
    Rails.application.load_tasks

    # Set up test directories
    @test_articles_dir = Rails.root.join('spec', 'fixtures', 'files')
    @test_projects_dir = Rails.root.join('spec', 'fixtures', 'files')

    # Clean up any existing test data
    Article.where(slug: 'test-article').destroy_all
    Project.where(title: 'Test Project').destroy_all
  end

  after do
    # Clean up test data
    Article.where(slug: 'test-article').destroy_all
    Project.where(title: 'Test Project').destroy_all
  end

  it 'imports articles and projects from the specified directories' do
    # Reset the task
    Rake::Task['db:import'].reenable

    # Execute the task with custom directories
    expect {
      Rake::Task['db:import'].invoke(@test_articles_dir.to_s, @test_projects_dir.to_s)
    }.to change(Article, :count).by(1).and change(Project, :count).by(1)

    # Verify the imported data
    article = Article.find_by(slug: 'test-article')
    expect(article).to be_present
    expect(article.title).to eq('Test Article')

    project = Project.find_by(title: 'Test Project')
    expect(project).to be_present
    expect(project.icon).to eq('fa-flask')
  end
end
