# frozen_string_literal: true

module Admin
  class DashboardController < BaseController
    def index
      @availability = ::WorkHour::AvailabilityCalculator.new(months_ahead: 3)
      @recent_work_entries = ::WorkHour::WorkEntry.order(worked_on: :desc).limit(10)
      @active_projects = ::WorkHour::Project.active.includes(:client).order(:name)
      @current_month = Date.current.beginning_of_month
      @current_month_entries = ::WorkHour::WorkEntry.for_month(@current_month)
      @current_month_total_hours = @current_month_entries.sum(:minutes) / 60.0
    end
  end
end
