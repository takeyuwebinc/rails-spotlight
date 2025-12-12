# frozen_string_literal: true

module WorkHour
  class Client < ApplicationRecord
    has_many :projects, class_name: "WorkHour::Project", dependent: :nullify

    validates :code, presence: true, uniqueness: true
    validates :name, presence: true

    def self.generate_code_from_name(name)
      return "" if name.blank?

      # Downcase, replace spaces and special chars with hyphens, remove consecutive hyphens
      name
        .downcase
        .gsub(/[^a-z0-9\s-]/, "")
        .gsub(/\s+/, "-")
        .gsub(/-+/, "-")
        .gsub(/^-|-$/, "")
    end
  end
end
