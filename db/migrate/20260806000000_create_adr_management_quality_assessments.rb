# frozen_string_literal: true

class CreateAdrManagementQualityAssessments < ActiveRecord::Migration[8.1]
  def change
    create_table :adr_management_quality_assessments do |t|
      t.integer :adr_id, null: false
      t.string :layer, null: false
      t.string :content_fingerprint, null: false
      t.json :findings, null: false
      t.datetime :reviewed_at
      t.string :origin, null: false
      t.timestamps
    end
    add_index :adr_management_quality_assessments, [ :adr_id, :layer ],
      name: "idx_adr_quality_assessments_on_adr_and_layer"
    add_index :adr_management_quality_assessments, :reviewed_at,
      name: "idx_adr_quality_assessments_on_reviewed_at"
  end
end
