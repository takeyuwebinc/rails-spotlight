require "securerandom"

class CustomHtmlRenderer < Redcarpet::Render::HTML
  attr_reader :placeholders

  def preprocess(document)
    @placeholders = {}
    convert_custom_blocks_to_placeholder(document)
  end

  def postprocess(document)
    convert_custom_placeholder_to_html(document)
  end

  private

  def convert_custom_blocks_to_placeholder(text)
    # Process ::::details blocks (4 colons for outer blocks)
    text = text.gsub(/^::::details\s+(.+?)\s*$\n(.*?)^::::\s*$/m) do
      title = $1.strip
      content = $2
      placeholder = SecureRandom.uuid

      placeholders[placeholder] = {
        type: :details,
        title: title,
        content: content
      }

      placeholder
    end

    # Process :::details blocks (3 colons for regular or inner blocks)
    text = text.gsub(/^:::details\s+(.+?)\s*$\n(.*?)^:::\s*$/m) do
      title = $1.strip
      content = $2
      placeholder = SecureRandom.uuid

      placeholders[placeholder] = {
        type: :details,
        title: title,
        content: content
      }

      placeholder
    end

    # Process ::::message blocks (4 colons for outer blocks)
    text = text.gsub(/^::::message\s*$\n(.*?)^::::\s*$/m) do
      content = $1
      placeholder = SecureRandom.uuid

      placeholders[placeholder] = {
        type: :message,
        content: content
      }

      placeholder
    end

    # Process :::message blocks (3 colons for regular or inner blocks)
    text = text.gsub(/^:::message\s*$\n(.*?)^:::\s*$/m) do
      content = $1
      placeholder = SecureRandom.uuid

      placeholders[placeholder] = {
        type: :message,
        content: content
      }

      placeholder
    end

    # Process ::::message alert blocks (4 colons for outer blocks)
    text = text.gsub(/^::::message\s+alert\s*$\n(.*?)^::::\s*$/m) do
      content = $1
      placeholder = SecureRandom.uuid

      placeholders[placeholder] = {
        type: :message_alert,
        content: content
      }

      placeholder
    end

    # Process :::message alert blocks (3 colons for regular or inner blocks)
    text = text.gsub(/^:::message\s+alert\s*$\n(.*?)^:::\s*$/m) do
      content = $1
      placeholder = SecureRandom.uuid

      placeholders[placeholder] = {
        type: :message_alert,
        content: content
      }

      placeholder
    end

    text
  end

  def convert_custom_placeholder_to_html(text)
    # Now recursively process placeholders
    placeholders.each do |placeholder, data|
      # Render the content with Redcarpet
      html_content = render_markdown(data[:content])

      # Generate the final HTML based on the block type
      final_html = case data[:type]
      when :details
        # Wrap content in a paragraph with the appropriate class if it's not already wrapped
        content_with_class = if html_content.strip.start_with?("<p")
                              html_content.gsub(/<p>/, '<p class="text-sm text-gray-600">')
        else
                              "<p class=\"text-sm text-gray-600\">#{html_content}</p>"
        end

        %(<div class="border border-gray-200 rounded mb-4" data-controller="details"><button data-action="click->details#toggle" class="flex justify-between items-center w-full p-4 text-left text-sm font-medium text-gray-700 hover:bg-gray-50 focus:outline-none"><span>#{data[:title]}</span><svg class="h-5 w-5 text-gray-500 transition-transform duration-200" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clip-rule="evenodd" /></svg></button><div data-details-target="content" class="p-4 border-t border-gray-200 bg-gray-50">#{content_with_class}</div></div>)
      when :message
        # Wrap content in a paragraph with the appropriate class if it's not already wrapped
        content_with_class = if html_content.strip.start_with?("<p")
                              html_content.gsub(/<p>/, '<p class="text-sm text-amber-800">')
        else
                              "<p class=\"text-sm text-amber-800\">#{html_content}</p>"
        end

        %(<div class="bg-amber-50 border-l-4 border-amber-400 p-4 mb-4 rounded-r">#{content_with_class}</div>)
      when :message_alert
        # Wrap content in a paragraph with the appropriate class if it's not already wrapped
        content_with_class = if html_content.strip.start_with?("<p")
                              html_content.gsub(/<p>/, '<p class="text-sm text-red-800">')
        else
                              "<p class=\"text-sm text-red-800\">#{html_content}</p>"
        end

        %(<div class="bg-red-50 border-l-4 border-red-400 p-4 mb-4 rounded-r">#{content_with_class}</div>)
      end

      # Replace the placeholder with the final HTML
      text.gsub!(placeholder) { final_html }
      text.gsub!("<p><div ") { "<div " }
      text.gsub!("</div></p>") { "</div>" }
    end
    text
  end

  def render_markdown(text)
    # Create a new Redcarpet instance to render inner content
    renderer = CustomHtmlRenderer.new(hard_wrap: true)
    markdown = Redcarpet::Markdown.new(renderer, {
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      highlight: true,
      superscript: true,
      underline: true,
      quote: true
    })

    # Convert inner content from markdown to HTML
    markdown.render(text)
  end
end
