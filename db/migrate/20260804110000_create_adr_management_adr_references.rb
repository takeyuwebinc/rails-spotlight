# frozen_string_literal: true

class CreateAdrManagementAdrReferences < ActiveRecord::Migration[8.1]
  def change
    create_table :adr_management_adr_references do |t|
      t.integer :source_adr_id, null: false
      t.integer :target_adr_id, null: false
      t.datetime :created_at, null: false
    end
    add_index :adr_management_adr_references, [ :source_adr_id, :target_adr_id ],
      name: "idx_adr_references_on_source_and_target", unique: true
    add_index :adr_management_adr_references, :target_adr_id,
      name: "idx_adr_references_on_target"
  end
end
