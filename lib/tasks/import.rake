namespace :db do
  desc "Import content from docs/published directory (or specified directories)"
  task :import, [ :articles_dir, :projects_dir ] => :environment do |t, args|
    articles_dir = args[:articles_dir].presence || Rails.root.join("docs", "published", "articles")
    projects_dir = args[:projects_dir].presence || Rails.root.join("docs", "published", "projects")

    source_message = if articles_dir || projects_dir
      "Importing content from specified directories..."
    else
      "Importing content from docs/published directory..."
    end
    puts source_message

    # Import articles
    article_count = Article.import_from_docs(articles_dir)
    puts "Imported #{article_count} articles"

    # Import projects
    project_count = Project.import_from_docs(projects_dir)
    puts "Imported #{project_count} projects"

    puts "Import completed"
  end
end
