require "breaker/version"

module Breaker
  CircuitOpenError = Class.new RuntimeError

  class Circuit
    attr_accessor :failure_threshold

    def initialize(options = {})
      options.each_pair do |key, value|
        send "#{key}=", value
      end

      @state = :closed
      @failure_count = 0
    end

    def open?
      @state == :open
    end

    def closed?
      @state == :closed
    end

    def run
      raise CircuitOpenError if open?

      begin
        yield
      rescue => ex
        failed
        raise ex
      end
    end

    private
    def failed
      @failure_count = @failure_count + 1

      if @failure_count >= @failure_threshold
        @state = :open
      end
    end
  end
end
