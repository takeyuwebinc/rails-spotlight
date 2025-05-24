class ChangeTagColorToSeparateColors < ActiveRecord::Migration[8.0]
  def up
    # Add new color columns
    add_column :tags, :bg_color, :string
    add_column :tags, :text_color, :string

    # Migrate existing data
    Tag.reset_column_information
    Tag.find_each do |tag|
      colors = migrate_color(tag.color)
      tag.update_columns(
        bg_color: colors[:bg_color],
        text_color: colors[:text_color]
      )
    end

    # Make new columns not null
    change_column_null :tags, :bg_color, false
    change_column_null :tags, :text_color, false

    # Remove old color column
    remove_column :tags, :color
  end

  def down
    # Add back the old color column
    add_column :tags, :color, :string, default: "gray"

    # Migrate data back (simplified mapping)
    Tag.reset_column_information
    Tag.find_each do |tag|
      # Extract base color from bg_color (e.g., "purple-600" -> "purple")
      base_color = tag.bg_color.split('-').first
      tag.update_columns(color: base_color)
    end

    # Remove new columns
    remove_column :tags, :bg_color
    remove_column :tags, :text_color
  end

  private

  def migrate_color(old_color)
    case old_color
    when "red"
      { bg_color: "red-600", text_color: "red-100" }
    when "blue"
      { bg_color: "blue-600", text_color: "blue-100" }
    when "green"
      { bg_color: "green-600", text_color: "green-100" }
    when "yellow"
      { bg_color: "yellow-500", text_color: "yellow-900" }
    when "purple"
      { bg_color: "purple-600", text_color: "purple-100" }
    when "orange"
      { bg_color: "orange-600", text_color: "orange-100" }
    when "pink"
      { bg_color: "pink-600", text_color: "pink-100" }
    when "indigo"
      { bg_color: "indigo-600", text_color: "indigo-100" }
    else
      { bg_color: "gray-600", text_color: "gray-100" }
    end
  end
end
