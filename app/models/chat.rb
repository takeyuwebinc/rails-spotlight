class Chat < ApplicationRecord
  TITLE_MAX_LENGTH = 50

  acts_as_chat

  has_many :pending_changes, class_name: "ContentAgent::PendingChange", dependent: :destroy
  has_many :task_usages, class_name: "ContentAgent::TaskUsage", dependent: :destroy

  scope :recent, -> { order(updated_at: :desc) }

  # タイトルが未設定のとき、発言テキストの先頭を切り詰めて設定する。
  # 設定済み・空白のみの発言では何もしない。
  def assign_title_from(text)
    return if title.present?

    candidate = text.to_s.strip
    return if candidate.blank?

    update!(title: candidate.truncate(TITLE_MAX_LENGTH, omission: ""))
  end
end
