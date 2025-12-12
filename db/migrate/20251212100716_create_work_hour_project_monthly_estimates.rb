class CreateWorkHourProjectMonthlyEstimates < ActiveRecord::Migration[8.0]
  def change
    create_table :work_hour_project_monthly_estimates do |t|
      t.references :project, null: false, foreign_key: { to_table: :work_hour_projects }
      t.date :year_month, null: false
      t.decimal :estimated_hours, null: false, precision: 5, scale: 1

      t.timestamps
    end
    add_index :work_hour_project_monthly_estimates, %i[project_id year_month], unique: true, name: "idx_work_hour_estimates_on_project_and_month"
  end
end
