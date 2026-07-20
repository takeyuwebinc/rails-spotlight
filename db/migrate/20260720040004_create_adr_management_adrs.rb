class CreateAdrManagementAdrs < ActiveRecord::Migration[8.1]
  def change
    create_table :adr_management_adrs do |t|
      t.integer :engagement_id, null: false
      t.integer :project_id
      t.integer :number, null: false
      t.string :title, null: false
      t.string :status, null: false
      t.string :confidence, null: false
      t.date :decided_on, null: false
      t.text :context, null: false
      t.text :decision, null: false
      t.text :consequences, null: false
      t.text :alternatives
      t.text :reevaluation_conditions
      t.text :reference_links

      t.timestamps
    end
    add_index :adr_management_adrs, [ :engagement_id, :number ], unique: true,
      name: "idx_adr_management_adrs_on_engagement_and_number"
    add_index :adr_management_adrs, :project_id

    create_table :adr_management_supersessions do |t|
      t.integer :superseding_adr_id, null: false
      t.integer :superseded_adr_id, null: false
      t.datetime :created_at, null: false
    end
    add_index :adr_management_supersessions, :superseding_adr_id,
      name: "idx_adr_management_supersessions_on_superseding"
    add_index :adr_management_supersessions, :superseded_adr_id, unique: true,
      name: "idx_adr_management_supersessions_on_superseded"

    create_table :adr_management_adr_revisions do |t|
      t.integer :adr_id, null: false
      t.json :snapshot
      t.json :changed_fields
      t.string :change_type, null: false
      t.string :origin, null: false
      t.datetime :created_at, null: false
    end
    add_index :adr_management_adr_revisions, :adr_id
  end
end
