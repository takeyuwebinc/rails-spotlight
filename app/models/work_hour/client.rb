# frozen_string_literal: true

module WorkHour
  # 工数管理ドメインにおける取引先の拡張。識別属性（code・name）は
  # ドメイン横断の共有クライアント（Client）が保持し、本モデルは
  # 共有クライアントへの参照とドメイン固有の関連（projects）のみを持つ。
  class Client < ApplicationRecord
    belongs_to :shared_client, class_name: "::Client", foreign_key: :client_id,
      optional: true, autosave: true, validate: false
    has_many :projects, class_name: "WorkHour::Project", dependent: :nullify

    validate :shared_client_assigned
    validate :shared_client_valid
    validate :shared_client_not_taken

    delegate :code, :name, to: :shared_client, allow_nil: true

    scope :ordered_by_code, -> { eager_load(:shared_client).order("clients.code") }
    scope :ordered_by_name, -> { eager_load(:shared_client).order("clients.name") }

    def self.find_by_code(code)
      joins(:shared_client).find_by(clients: { code: code })
    end

    # code は取引先をドメイン間で同一視するキー。同じ code の共有クライアントが
    # あればそれを同一実体として参照し、なければ新規作成する。これにより
    # 他ドメインで登録済みの取引先が二重登録されない。
    def code=(value)
      return if shared_client&.code == value

      carried_name = @assigned_name || shared_client&.name
      self.shared_client = ::Client.find_or_initialize_by(code: value)
      shared_client.name = carried_name if shared_client.new_record? && carried_name
    end

    def name=(value)
      @assigned_name = value
      shared_client.name = value if shared_client
    end

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

    private

    def shared_client_assigned
      return if shared_client

      errors.add(:code, :blank)
      errors.add(:name, :blank)
    end

    def shared_client_valid
      return if shared_client.nil? || shared_client.valid?

      shared_client.errors.each do |error|
        errors.add(error.attribute, error.message) if %i[code name].include?(error.attribute)
      end
    end

    def shared_client_not_taken
      return if shared_client.nil? || !shared_client.persisted?

      taken = self.class.where(client_id: shared_client.id).where.not(id: id).exists?
      errors.add(:code, :taken) if taken
    end
  end
end
