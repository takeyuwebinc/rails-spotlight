# frozen_string_literal: true

ActionResult = Data.define(:success?, :data, :errors) do
  def self.success(data = nil)
    new(success?: true, data: data, errors: [])
  end

  def self.failure(errors)
    new(success?: false, data: nil, errors: Array(errors))
  end

  def failure?
    !success?
  end
end
