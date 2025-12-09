require 'rails_helper'
require 'rake'

RSpec.describe 'db:import task' do
  before do
    # Load the Rails application tasks
    Rails.application.load_tasks

    # Set up test directories
    @test_projects_dir = Rails.root.join('spec', 'fixtures', 'files')

    # Clean up any existing test data
    Project.where(title: 'Test Project').destroy_all
  end

  after do
    # Clean up test data
    Project.where(title: 'Test Project').destroy_all
  end

  it 'imports projects from the specified directories' do
    # Reset the task
    Rake::Task['db:import'].reenable

    # Execute the task with custom directories
    expect {
      Rake::Task['db:import'].invoke(@test_projects_dir.to_s)
    }.to change(Project, :count).by(1)

    # Verify the imported data
    project = Project.find_by(title: 'Test Project')
    expect(project).to be_present
    expect(project.icon).to eq('fa-flask')
  end
end
