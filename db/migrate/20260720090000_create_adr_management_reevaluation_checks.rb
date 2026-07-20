# frozen_string_literal: true

class CreateAdrManagementReevaluationChecks < ActiveRecord::Migration[8.1]
  def change
    create_table :adr_management_reevaluation_checks do |t|
      t.integer :adr_id, null: false
      t.date :checked_on, null: false
      t.string :result, null: false
      t.text :note
      t.string :origin, null: false
      t.datetime :created_at, null: false
    end
    add_index :adr_management_reevaluation_checks, [ :adr_id, :checked_on ],
      name: "idx_adr_reevaluation_checks_on_adr_and_checked_on"
  end
end
