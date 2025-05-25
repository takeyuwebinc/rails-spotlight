# frozen_string_literal: true

require "rails_helper"

RSpec.describe MetadataParser do
  describe ".parse" do
    context "with valid article metadata" do
      let(:file_content) do
        <<~MARKDOWN
          ---
          title: Test Article
          slug: test-article
          category: article
          published_date: 2025-01-15
          tags: Rails, Testing, Ruby
          description: A test article for validation
          ---

          This is the article content.
        MARKDOWN
      end

      it "parses metadata correctly" do
        result = described_class.parse(file_content)

        expect(result[:metadata]).to include(
          title: "Test Article",
          slug: "test-article",
          category: "article",
          published_date: Date.parse("2025-01-15"),
          tags: [ "Rails", "Testing", "Ruby" ],
          description: "A test article for validation"
        )
        expect(result[:content]).to eq("This is the article content.")
      end
    end

    context "with valid project metadata" do
      let(:file_content) do
        <<~MARKDOWN
          ---
          title: Test Project
          category: project
          published_date: 2025-02-15
          position: 3
          icon: fa-cloud
          color: blue-500
          technologies:
            - Rails
            - AWS
            - Docker
          ---

          This is the project description.
        MARKDOWN
      end

      it "parses metadata correctly" do
        result = described_class.parse(file_content)

        expect(result[:metadata]).to include(
          title: "Test Project",
          category: "project",
          published_date: Date.parse("2025-02-15"),
          position: 3,
          icon: "fa-cloud",
          color: "blue-500",
          technologies: "Rails, AWS, Docker"
        )
        expect(result[:content]).to eq("This is the project description.")
      end
    end

    context "with comma-separated tags" do
      let(:file_content) do
        <<~MARKDOWN
          ---
          title: Test Article
          slug: test-article
          category: article
          published_date: 2025-01-15
          tags: Rails, Testing, Ruby
          description: A test article
          ---

          Content here.
        MARKDOWN
      end

      it "parses comma-separated tags correctly" do
        result = described_class.parse(file_content)
        expect(result[:metadata][:tags]).to eq([ "Rails", "Testing", "Ruby" ])
      end
    end

    context "with array format tags" do
      let(:file_content) do
        <<~MARKDOWN
          ---
          title: Test Article
          slug: test-article
          category: article
          published_date: 2025-01-15
          tags:
            - Rails
            - Testing
            - Ruby
          description: A test article
          ---

          Content here.
        MARKDOWN
      end

      it "parses array format tags correctly" do
        result = described_class.parse(file_content)
        expect(result[:metadata][:tags]).to eq([ "Rails", "Testing", "Ruby" ])
      end
    end

    context "with comma-separated technologies" do
      let(:file_content) do
        <<~MARKDOWN
          ---
          title: Test Project
          category: project
          published_date: 2025-02-15
          technologies: Rails, AWS, Docker
          ---

          Project description.
        MARKDOWN
      end

      it "parses comma-separated technologies correctly" do
        result = described_class.parse(file_content)
        expect(result[:metadata][:technologies]).to eq("Rails, AWS, Docker")
      end
    end

    context "with project defaults" do
      let(:file_content) do
        <<~MARKDOWN
          ---
          title: Test Project
          category: project
          published_date: 2025-02-15
          ---

          Project description.
        MARKDOWN
      end

      it "applies default values for optional fields" do
        result = described_class.parse(file_content)

        expect(result[:metadata]).to include(
          icon: "fa-code",
          color: "blue-600",
          position: 999
        )
      end
    end

    context "with invalid YAML syntax" do
      let(:file_content) do
        <<~MARKDOWN
          ---
          title: Test Article
          invalid_yaml: [unclosed array
          ---

          Content here.
        MARKDOWN
      end

      it "raises MetadataParseError" do
        expect { described_class.parse(file_content) }
          .to raise_error(MetadataParser::MetadataParseError, /Invalid YAML syntax/)
      end
    end

    context "without frontmatter" do
      let(:file_content) { "Just plain markdown content without frontmatter." }

      it "raises MetadataParseError" do
        expect { described_class.parse(file_content) }
          .to raise_error(MetadataParser::MetadataParseError, /does not contain valid YAML frontmatter/)
      end
    end

    context "with missing required fields for article" do
      let(:file_content) do
        <<~MARKDOWN
          ---
          title: Test Article
          category: article
          ---

          Content here.
        MARKDOWN
      end

      it "raises MetadataParseError" do
        expect { described_class.parse(file_content) }
          .to raise_error(MetadataParser::MetadataParseError, /Missing required fields/)
      end
    end

    context "with missing required fields for project" do
      let(:file_content) do
        <<~MARKDOWN
          ---
          category: project
          ---

          Content here.
        MARKDOWN
      end

      it "raises MetadataParseError" do
        expect { described_class.parse(file_content) }
          .to raise_error(MetadataParser::MetadataParseError, /Missing required fields/)
      end
    end

    context "with unknown category" do
      let(:file_content) do
        <<~MARKDOWN
          ---
          title: Test
          category: unknown
          ---

          Content here.
        MARKDOWN
      end

      it "raises MetadataParseError" do
        expect { described_class.parse(file_content) }
          .to raise_error(MetadataParser::MetadataParseError, /Unknown category/)
      end
    end

    context "with invalid date format" do
      let(:file_content) do
        <<~MARKDOWN
          ---
          title: Test Article
          slug: test-article
          category: article
          published_date: invalid-date
          description: A test article
          ---

          Content here.
        MARKDOWN
      end

      it "raises MetadataParseError" do
        expect { described_class.parse(file_content) }
          .to raise_error(MetadataParser::MetadataParseError, /Invalid date/)
      end
    end

    context "with non-hash frontmatter" do
      let(:file_content) do
        <<~MARKDOWN
          ---
          - item1
          - item2
          ---

          Content here.
        MARKDOWN
      end

      it "raises MetadataParseError" do
        expect { described_class.parse(file_content) }
          .to raise_error(MetadataParser::MetadataParseError, /Frontmatter must be a YAML hash/)
      end
    end

    context "with Date object in metadata" do
      let(:metadata_hash) do
        {
          "title" => "Test Article",
          "slug" => "test-article",
          "category" => "article",
          "published_date" => Date.parse("2025-01-15"),
          "description" => "A test article"
        }
      end
      let(:file_content) do
        "---\n#{metadata_hash.to_yaml}---\n\nContent here."
      end

      it "handles Date objects correctly" do
        result = described_class.parse(file_content)
        expect(result[:metadata][:published_date]).to eq(Date.parse("2025-01-15"))
      end
    end

    context "with invalid tags format" do
      let(:file_content) do
        <<~MARKDOWN
          ---
          title: Test Article
          slug: test-article
          category: article
          published_date: 2025-01-15
          tags: 123
          description: A test article
          ---

          Content here.
        MARKDOWN
      end

      it "raises MetadataParseError" do
        expect { described_class.parse(file_content) }
          .to raise_error(MetadataParser::MetadataParseError, /Tags must be an array or comma-separated string/)
      end
    end

    context "with invalid technologies format" do
      let(:file_content) do
        <<~MARKDOWN
          ---
          title: Test Project
          category: project
          published_date: 2025-02-15
          technologies: 123
          ---

          Project description.
        MARKDOWN
      end

      it "raises MetadataParseError" do
        expect { described_class.parse(file_content) }
          .to raise_error(MetadataParser::MetadataParseError, /Technologies must be an array or comma-separated string/)
      end
    end
  end
end
