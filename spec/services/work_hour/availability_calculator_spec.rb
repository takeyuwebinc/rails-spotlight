# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorkHour::AvailabilityCalculator do
  describe "#monthly_availability" do
    context "when no estimates exist" do
      it "returns 0% for all months" do
        calculator = described_class.new(months_ahead: 3)
        result = calculator.monthly_availability

        expect(result.length).to eq(3)
        expect(result.all? { |entry| entry[:rate] == 0 }).to be true
      end
    end

    context "when estimates exist" do
      let(:project) { create(:work_hour_project, status: "active") }

      it "calculates rate based on estimated hours" do
        target_month = Date.current.beginning_of_month
        create(:work_hour_project_monthly_estimate, project: project, year_month: target_month, estimated_hours: 80)

        calculator = described_class.new(months_ahead: 3)
        result = calculator.monthly_availability

        expect(result.first[:rate]).to eq(50)
      end

      it "caps rate at 100%" do
        target_month = Date.current.beginning_of_month
        create(:work_hour_project_monthly_estimate, project: project, year_month: target_month, estimated_hours: 200)

        calculator = described_class.new(months_ahead: 3)
        result = calculator.monthly_availability

        expect(result.first[:rate]).to eq(100)
      end

      it "ignores estimates from closed projects" do
        closed_project = create(:work_hour_project, status: "closed")
        target_month = Date.current.beginning_of_month
        create(:work_hour_project_monthly_estimate, project: closed_project, year_month: target_month, estimated_hours: 160)

        calculator = described_class.new(months_ahead: 3)
        result = calculator.monthly_availability

        expect(result.first[:rate]).to eq(0)
      end
    end
  end

  describe "#current_rate" do
    it "returns rate for current month" do
      project = create(:work_hour_project, status: "active")
      create(:work_hour_project_monthly_estimate, project: project, year_month: Date.current.beginning_of_month, estimated_hours: 120)

      calculator = described_class.new
      expect(calculator.current_rate).to eq(75)
    end
  end

  describe "#next_available_month" do
    context "when current month is under 100%" do
      it "returns current month" do
        calculator = described_class.new
        expect(calculator.next_available_month).to eq(Date.current.beginning_of_month.strftime("%Y年%m月"))
      end
    end

    context "when all months are at 100%" do
      let(:project) { create(:work_hour_project, status: "active") }

      it "returns message indicating beyond the period" do
        3.times do |i|
          create(:work_hour_project_monthly_estimate,
                 project: project,
                 year_month: Date.current.next_month(i).beginning_of_month,
                 estimated_hours: 160)
        end

        calculator = described_class.new(months_ahead: 3)
        expect(calculator.next_available_month).to eq("3ヶ月以降")
      end
    end
  end

  describe "#status" do
    let(:project) { create(:work_hour_project, status: "active") }

    it "returns '満稼働' when at 100%" do
      create(:work_hour_project_monthly_estimate,
             project: project,
             year_month: Date.current.beginning_of_month,
             estimated_hours: 160)

      calculator = described_class.new
      expect(calculator.status).to eq("満稼働")
    end

    it "returns 'ほぼ満稼働' when at 80-99%" do
      create(:work_hour_project_monthly_estimate,
             project: project,
             year_month: Date.current.beginning_of_month,
             estimated_hours: 140)

      calculator = described_class.new
      expect(calculator.status).to eq("ほぼ満稼働")
    end

    it "returns '一部受付可' when at 50-79%" do
      create(:work_hour_project_monthly_estimate,
             project: project,
             year_month: Date.current.beginning_of_month,
             estimated_hours: 100)

      calculator = described_class.new
      expect(calculator.status).to eq("一部受付可")
    end

    it "returns '受付可' when under 50%" do
      calculator = described_class.new
      expect(calculator.status).to eq("受付可")
    end
  end

  describe "#monthly_availability with project_breakdown" do
    context "when estimates exist for multiple projects" do
      let(:project1) { create(:work_hour_project, name: "プロジェクトA", status: "active") }
      let(:project2) { create(:work_hour_project, name: "プロジェクトB", status: "active") }

      it "includes project_breakdown sorted by estimated_hours descending" do
        target_month = Date.current.beginning_of_month
        create(:work_hour_project_monthly_estimate, project: project1, year_month: target_month, estimated_hours: 40)
        create(:work_hour_project_monthly_estimate, project: project2, year_month: target_month, estimated_hours: 80)

        calculator = described_class.new(months_ahead: 3)
        result = calculator.monthly_availability

        breakdown = result.first[:project_breakdown]
        expect(breakdown.length).to eq(2)
        expect(breakdown.first[:project_name]).to eq("プロジェクトB")
        expect(breakdown.first[:estimated_hours]).to eq(80)
        expect(breakdown.second[:project_name]).to eq("プロジェクトA")
        expect(breakdown.second[:estimated_hours]).to eq(40)
      end
    end

    context "when no estimates exist" do
      it "returns empty project_breakdown" do
        calculator = described_class.new(months_ahead: 3)
        result = calculator.monthly_availability

        expect(result.first[:project_breakdown]).to eq([])
      end
    end

    context "when estimates exist for closed projects" do
      let(:active_project) { create(:work_hour_project, name: "アクティブ", status: "active") }
      let(:closed_project) { create(:work_hour_project, name: "終了済み", status: "closed") }

      it "excludes closed projects from breakdown" do
        target_month = Date.current.beginning_of_month
        create(:work_hour_project_monthly_estimate, project: active_project, year_month: target_month, estimated_hours: 80)
        create(:work_hour_project_monthly_estimate, project: closed_project, year_month: target_month, estimated_hours: 40)

        calculator = described_class.new(months_ahead: 3)
        result = calculator.monthly_availability

        breakdown = result.first[:project_breakdown]
        expect(breakdown.length).to eq(1)
        expect(breakdown.first[:project_name]).to eq("アクティブ")
      end
    end
  end
end
