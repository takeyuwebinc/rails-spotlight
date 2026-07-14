# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorkHour::BudgetConsumption do
  describe "#actual_hours" do
    it "converts minutes to hours" do
      consumption = described_class.new(budget_hours: 100, actual_minutes: 90)
      expect(consumption.actual_hours).to eq(1.5)
    end

    it "is 0.0 without actual minutes" do
      consumption = described_class.new(budget_hours: 100, actual_minutes: 0)
      expect(consumption.actual_hours).to eq(0.0)
    end
  end

  describe "#rate" do
    it "is the rounded percentage of actual hours against the budget" do
      # 実績 60 時間 / 予算 100 時間 = 60%
      consumption = described_class.new(budget_hours: 100, actual_minutes: 3600)
      expect(consumption.rate).to eq(60)
    end

    it "rounds to the nearest integer" do
      # 実績 1 時間 / 予算 3 時間 = 33.33...%
      consumption = described_class.new(budget_hours: 3, actual_minutes: 60)
      expect(consumption.rate).to eq(33)
    end

    it "is nil when the budget is not registered" do
      consumption = described_class.new(budget_hours: nil, actual_minutes: 3600)
      expect(consumption.rate).to be_nil
    end

    it "exceeds 100 without capping" do
      # 実績 120 時間 / 予算 100 時間 = 120%
      consumption = described_class.new(budget_hours: 100, actual_minutes: 7200)
      expect(consumption.rate).to eq(120)
    end

    it "accepts a decimal budget" do
      consumption = described_class.new(budget_hours: BigDecimal("120.5"), actual_minutes: 3615)
      expect(consumption.rate).to eq(50)
    end
  end

  describe "#status" do
    it "is :normal below the caution rate" do
      consumption = described_class.new(budget_hours: 100, actual_minutes: 5340) # 89%
      expect(consumption.status).to eq(:normal)
    end

    it "is :caution at the caution rate" do
      consumption = described_class.new(budget_hours: 100, actual_minutes: 5400) # 90%
      expect(consumption.status).to eq(:caution)
      expect(consumption).to be_caution
    end

    it "is :caution at exactly 100%" do
      consumption = described_class.new(budget_hours: 100, actual_minutes: 6000)
      expect(consumption.status).to eq(:caution)
    end

    it "is :over above 100%" do
      consumption = described_class.new(budget_hours: 100, actual_minutes: 6060) # 101%
      expect(consumption.status).to eq(:over)
      expect(consumption).to be_over
    end

    it "is nil when the budget is not registered" do
      consumption = described_class.new(budget_hours: nil, actual_minutes: 6000)
      expect(consumption.status).to be_nil
      expect(consumption).not_to be_over
      expect(consumption).not_to be_caution
    end
  end
end
