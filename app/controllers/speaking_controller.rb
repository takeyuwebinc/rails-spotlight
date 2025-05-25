class SpeakingController < ApplicationController
  def index
    @speaking_engagements = SpeakingEngagement.published.ordered
  end
end
