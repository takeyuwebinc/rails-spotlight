# frozen_string_literal: true

module Admin
  module WorkHour
    class ProjectsController < BaseController
      before_action :set_project, only: %i[show edit update destroy]

      def index
        @projects = ::WorkHour::Project.includes(:client).order(:name)
        actual_minutes = ::WorkHour::WorkEntry.total_minutes_by_project
        @budget_consumptions = @projects.to_h do |project|
          [ project.id, ::WorkHour::BudgetConsumption.new(budget_hours: project.budget_hours, actual_minutes: actual_minutes[project.id]) ]
        end
      end

      def show
        @monthly_estimates = @project.monthly_estimates.order(year_month: :desc)
        @actual_minutes_by_month = ::WorkHour::WorkEntry.total_minutes_by_month(@project).sort_by { |month, _| month }.reverse
        @budget_consumption = ::WorkHour::BudgetConsumption.new(
          budget_hours: @project.budget_hours,
          actual_minutes: @actual_minutes_by_month.sum { |_, minutes| minutes }
        )
      end

      def new
        @project = ::WorkHour::Project.new
      end

      def edit
      end

      def create
        @project = ::WorkHour::Project.new(project_params)

        if @project.save
          redirect_to admin_work_hour_project_path(@project), notice: "案件を作成しました。"
        else
          render :new, status: :unprocessable_entity
        end
      end

      def update
        if @project.update(project_params)
          redirect_to admin_work_hour_project_path(@project), notice: "案件を更新しました。"
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        if @project.destroy
          redirect_to admin_work_hour_projects_path, notice: "案件を削除しました。"
        else
          redirect_to admin_work_hour_project_path(@project), alert: @project.errors.full_messages.join(", ")
        end
      end

      private

      def set_project
        @project = ::WorkHour::Project.find(params[:id])
      end

      def project_params
        params.require(:work_hour_project).permit(:code, :name, :client_id, :color, :start_date, :end_date, :status, :budget_hours)
      end
    end
  end
end
