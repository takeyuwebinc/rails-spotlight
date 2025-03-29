# frozen_string_literal: true

class BadgeComponent < ViewComponent::Base
  def initialize(text: "badge", bg_color: "bg-gray-200", text_color: "text-black")
    @text = text
    @bg_color = bg_color
    @text_color = text_color
  end
end
