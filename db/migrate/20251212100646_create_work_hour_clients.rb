class CreateWorkHourClients < ActiveRecord::Migration[8.0]
  def change
    create_table :work_hour_clients do |t|
      t.string :code, null: false
      t.string :name, null: false

      t.timestamps
    end
    add_index :work_hour_clients, :code, unique: true
  end
end
