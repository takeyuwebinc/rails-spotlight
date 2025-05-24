# frozen_string_literal: true

class BadgeComponent < ViewComponent::Base
  def initialize(text: "badge", bg_color: "bg-gray-200", text_color: "text-black", href: nil)
    @text = text
    @bg_color = bg_color
    @text_color = text_color
    @href = href
  end

  private

  attr_reader :text, :bg_color, :text_color, :href
end
