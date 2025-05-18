require "rails_helper"

RSpec.describe ApplicationService do
  describe ".call" do
    it "instantiates the service and calls #call" do
      service = double("service")
      expect(service).to receive(:call)

      service_class = Class.new(ApplicationService) do
        define_method(:initialize) { }
        define_method(:call) { service.call }
      end

      service_class.call
    end
  end

  describe "#call" do
    it "raises NotImplementedError" do
      expect { ApplicationService.new.call }.to raise_error(NotImplementedError)
    end
  end
end
