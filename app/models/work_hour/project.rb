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
    # 予算工数は未登録（nil）を許容する。0時間の予算は業務上意味を持たず、
    # 消化率の算出で0除算になるため、正の値のみを受け付ける。
    validates :budget_hours, numericality: { greater_than: 0 }, allow_nil: true

    scope :active, -> { where(status: "active") }

    def active?
      status == "active"
    end
  end
end
