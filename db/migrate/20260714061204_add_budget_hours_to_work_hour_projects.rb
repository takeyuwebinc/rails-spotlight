class AddBudgetHoursToWorkHourProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :work_hour_projects, :budget_hours, :decimal, precision: 7, scale: 1
  end
end
