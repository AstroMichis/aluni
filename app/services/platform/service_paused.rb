# frozen_string_literal: true

module Platform
  # Raised by an outside-service client when the operator paused that service.
  # ApplicationJob holds the job, ApplicationController shows a calm notice.
  class ServicePaused < StandardError
    attr_reader :service

    def initialize(service)
      @service = service.to_s
      super("#{@service} is paused")
    end
  end
end
