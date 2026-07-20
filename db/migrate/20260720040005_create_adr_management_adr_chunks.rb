class CreateAdrManagementAdrChunks < ActiveRecord::Migration[8.1]
  def change
    create_table :adr_management_adr_chunks do |t|
      t.integer :adr_id, null: false
      t.string :kind, null: false
      t.text :content, null: false
      t.binary :embedding
      t.string :state, null: false, default: "stale"

      t.timestamps
    end
    add_index :adr_management_adr_chunks, :adr_id
    add_index :adr_management_adr_chunks, :state
  end
end
