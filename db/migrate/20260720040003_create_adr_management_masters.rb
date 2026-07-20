class CreateAdrManagementMasters < ActiveRecord::Migration[8.1]
  def change
    create_table :adr_management_clients do |t|
      t.integer :client_id, null: false

      t.timestamps
    end
    add_index :adr_management_clients, :client_id, unique: true

    create_table :adr_management_engagements do |t|
      t.integer :client_id, null: false
      t.string :code, null: false
      t.string :name, null: false
      t.text :description
      t.integer :max_issued_number, null: false, default: 0

      t.timestamps
    end
    add_index :adr_management_engagements, :client_id
    add_index :adr_management_engagements, :code, unique: true

    create_table :adr_management_projects do |t|
      t.integer :engagement_id, null: false
      t.string :name, null: false
      t.date :start_date
      t.date :end_date

      t.timestamps
    end
    add_index :adr_management_projects, :engagement_id
  end
end
