class CreateWorkHourWorkEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :work_hour_work_entries do |t|
      t.references :project, null: true, foreign_key: { to_table: :work_hour_projects }
      t.date :worked_on, null: false
      t.date :target_month, null: false
      t.text :description
      t.integer :minutes, null: false

      t.timestamps
    end
    add_index :work_hour_work_entries, :worked_on
    add_index :work_hour_work_entries, :target_month
  end
end
