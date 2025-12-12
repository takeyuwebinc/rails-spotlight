# frozen_string_literal: true

module Admin
  module WorkHour
    class MonthlyEstimatesController < BaseController
      before_action :set_project
      before_action :set_monthly_estimate, only: %i[edit update destroy]

      def new
        @monthly_estimate = @project.monthly_estimates.new
      end

      def edit
      end

      def create
        @monthly_estimate = @project.monthly_estimates.new(monthly_estimate_params)

        if @monthly_estimate.save
          redirect_to admin_work_hour_project_path(@project), notice: "見込み工数を登録しました。"
        else
          render :new, status: :unprocessable_entity
        end
      end

      def update
        if @monthly_estimate.update(monthly_estimate_params)
          redirect_to admin_work_hour_project_path(@project), notice: "見込み工数を更新しました。"
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @monthly_estimate.destroy
        redirect_to admin_work_hour_project_path(@project), notice: "見込み工数を削除しました。"
      end

      private

      def set_project
        @project = ::WorkHour::Project.find(params[:project_id])
      end

      def set_monthly_estimate
        @monthly_estimate = @project.monthly_estimates.find(params[:id])
      end

      def monthly_estimate_params
        params.require(:work_hour_project_monthly_estimate).permit(:year_month, :estimated_hours)
      end
    end
  end
end
