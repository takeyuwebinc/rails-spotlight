class AddDiscontinuedToUsesItems < ActiveRecord::Migration[8.0]
  def change
    add_column :uses_items, :discontinued, :boolean, default: false, null: false
  end
end
