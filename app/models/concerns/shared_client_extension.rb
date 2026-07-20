# frozen_string_literal: true

# 取引先のドメイン別拡張モデルに、共有クライアント（Client）への参照と
# 識別属性（code・name）の読み書きを提供する。
#
# code は取引先をドメイン間で同一視するキー。同じ code の共有クライアントが
# あればそれを同一実体として参照し、なければ新規作成する。これにより
# ドメイン間で取引先の二重登録・表記揺れが構造的に発生しない。
# 拡張モデルの削除は共有クライアント本体を残す（他ドメインが参照しうるため）。
module SharedClientExtension
  extend ActiveSupport::Concern

  included do
    belongs_to :shared_client, class_name: "::Client", foreign_key: :client_id,
      optional: true, autosave: true, validate: false

    validate :shared_client_assigned
    validate :shared_client_valid
    validate :shared_client_not_taken

    delegate :code, :name, to: :shared_client, allow_nil: true

    scope :ordered_by_code, -> { eager_load(:shared_client).order("clients.code") }
    scope :ordered_by_name, -> { eager_load(:shared_client).order("clients.name") }
  end

  class_methods do
    def find_by_code(code)
      joins(:shared_client).find_by(clients: { code: code })
    end
  end

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
