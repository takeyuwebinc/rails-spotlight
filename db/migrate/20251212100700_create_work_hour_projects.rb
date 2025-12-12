class CreateWorkHourProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :work_hour_projects do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.references :client, null: true, foreign_key: { to_table: :work_hour_clients }
      t.string :color, null: false, default: "#6366f1"
      t.date :start_date
      t.date :end_date
      t.string :status, null: false, default: "active"

      t.timestamps
    end
    add_index :work_hour_projects, :code, unique: true
  end
end
