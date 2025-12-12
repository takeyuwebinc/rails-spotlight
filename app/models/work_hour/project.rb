# frozen_string_literal: true

module WorkHour
  class Project < ApplicationRecord
    STATUSES = %w[active closed].freeze

    belongs_to :client, class_name: "WorkHour::Client", optional: true
    has_many :monthly_estimates, class_name: "WorkHour::ProjectMonthlyEstimate", dependent: :destroy
    has_many :work_entries, class_name: "WorkHour::WorkEntry", dependent: :restrict_with_error

    validates :code, presence: true, uniqueness: true
    validates :name, presence: true
    validates :color, presence: true
    validates :status, presence: true, inclusion: { in: STATUSES }

    scope :active, -> { where(status: "active") }

    def active?
      status == "active"
    end
  end
end
