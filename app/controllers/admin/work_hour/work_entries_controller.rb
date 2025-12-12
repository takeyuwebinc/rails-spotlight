# frozen_string_literal: true

module Admin
  module WorkHour
    class WorkEntriesController < BaseController
      before_action :set_work_entry, only: %i[edit update destroy]

      def index
        @date = params[:date].present? ? Date.parse(params[:date]) : Date.current
        @view_mode = params[:view_mode] || "week"
        @work_entries = fetch_work_entries
        @projects = ::WorkHour::Project.active.order(:name)
      end

      def new
        @work_entry = ::WorkHour::WorkEntry.new(
          worked_on: params[:date] || Date.current,
          target_month: (params[:date] || Date.current).to_date.beginning_of_month
        )
        @projects = ::WorkHour::Project.active.order(:name)
      end

      def edit
        @projects = ::WorkHour::Project.active.order(:name)
      end

      def create
        @work_entry = ::WorkHour::WorkEntry.new(work_entry_params)

        if @work_entry.save
          redirect_to admin_work_hour_work_entries_path(date: @work_entry.worked_on),
                      notice: "工数を登録しました。"
        else
          @projects = ::WorkHour::Project.active.order(:name)
          render :new, status: :unprocessable_entity
        end
      end

      def update
        if @work_entry.update(work_entry_params)
          redirect_to admin_work_hour_work_entries_path(date: @work_entry.worked_on),
                      notice: "工数を更新しました。"
        else
          @projects = ::WorkHour::Project.active.order(:name)
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        worked_on = @work_entry.worked_on
        @work_entry.destroy
        redirect_to admin_work_hour_work_entries_path(date: worked_on),
                    notice: "工数を削除しました。"
      end

      private

      def set_work_entry
        @work_entry = ::WorkHour::WorkEntry.find(params[:id])
      end

      def work_entry_params
        params.require(:work_hour_work_entry).permit(:project_id, :worked_on, :target_month, :description, :minutes)
      end

      def fetch_work_entries
        case @view_mode
        when "month"
          start_date = @date.beginning_of_month
          end_date = @date.end_of_month
        else # week
          start_date = @date.beginning_of_week
          end_date = @date.end_of_week
        end

        ::WorkHour::WorkEntry
          .includes(:project)
          .where(worked_on: start_date..end_date)
          .order(:worked_on, :created_at)
      end
    end
  end
end
