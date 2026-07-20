# frozen_string_literal: true

class ApplicationAction
  def self.perform(...)
    new(...).perform
  end

  private

  def success(data = nil)
    ActionResult.success(data)
  end

  def failure(errors)
    ActionResult.failure(errors)
  end
end
