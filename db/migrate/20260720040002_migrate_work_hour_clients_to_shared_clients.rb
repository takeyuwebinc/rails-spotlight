class MigrateWorkHourClientsToSharedClients < ActiveRecord::Migration[8.1]
  class MigrationWorkHourClient < ActiveRecord::Base
    self.table_name = "work_hour_clients"
  end

  class MigrationClient < ActiveRecord::Base
    self.table_name = "clients"
  end

  def up
    add_column :work_hour_clients, :client_id, :integer

    MigrationWorkHourClient.reset_column_information
    MigrationWorkHourClient.find_each do |work_hour_client|
      shared = MigrationClient.find_or_create_by!(code: work_hour_client.code) do |client|
        client.name = work_hour_client.name
      end
      work_hour_client.update_columns(client_id: shared.id)
    end

    change_column_null :work_hour_clients, :client_id, false
    add_index :work_hour_clients, :client_id, unique: true
    remove_index :work_hour_clients, :code
    remove_column :work_hour_clients, :code
    remove_column :work_hour_clients, :name
  end

  def down
    add_column :work_hour_clients, :code, :string
    add_column :work_hour_clients, :name, :string

    MigrationWorkHourClient.reset_column_information
    MigrationWorkHourClient.find_each do |work_hour_client|
      shared = MigrationClient.find(work_hour_client.client_id)
      work_hour_client.update_columns(code: shared.code, name: shared.name)
    end

    change_column_null :work_hour_clients, :code, false
    change_column_null :work_hour_clients, :name, false
    add_index :work_hour_clients, :code, unique: true
    remove_index :work_hour_clients, :client_id
    remove_column :work_hour_clients, :client_id
  end
end
