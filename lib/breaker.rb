require "breaker/version"

module Breaker
  CircuitOpenError = Class.new RuntimeError

  class Circuit
    attr_accessor :failure_threshold, :retry_timeout

    def initialize(options = {})
      options.each_pair do |key, value|
        send "#{key}=", value
      end

      @state = :closed
      @failure_count = 0
      @failed_at = nil
    end

    def open(clock = Time.now)
      @failed_at = clock
      @state = :open
    end

    def close
      @failure_count = 0
      @failed_at = nil
      @state = :closed
    end

    def open?
      @state == :open
    end

    def closed?
      @state == :closed
    end

    def run(clock = Time.now)
      raise CircuitOpenError if open? && !half_open?(clock)

      begin
        result = yield

        if half_open?(clock)
          close
        end

        result
      rescue => ex
        if closed?
          failed clock
        elsif half_open?(clock)
          failed clock
        end

        raise ex
      end
    end

    private
    def half_open?(clock)
      @failed_at && clock >= @failed_at + retry_timeout
    end

    def failed(clock)
      @failure_count = @failure_count + 1

      if @failure_count >= @failure_threshold
        open clock
      end
    end
  end
end
