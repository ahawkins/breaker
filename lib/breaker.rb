require "breaker/version"
require 'timeout'

module Breaker
  CircuitOpenError = Class.new RuntimeError

  class Circuit
    attr_accessor :failure_threshold, :retry_timeout, :timeout

    def initialize(options = {})
      options.each_pair do |key, value|
        send "#{key}=", value
      end

      @state = :closed
      @failure_count = 0
      @retry_threshold = nil
    end

    def open(clock = Time.now)
      @failure_count = 1
      @retry_threshold = clock + retry_timeout
      @state = :open
    end

    def close
      @failure_count = 0
      @retry_threshold = nil
      @state = :closed
    end

    def open?
      @state == :open
    end

    def closed?
      @state == :closed
    end

    def run(clock = Time.now)
      if closed? || half_open?(clock)
        begin
          result = Timeout.timeout timeout do
            yield
          end

          if half_open?(clock)
            close
          end

          result
        rescue => ex
          @failure_count = @failure_count + 1
          @retry_threshold = clock + retry_timeout

          open clock

          raise ex
        end
      else
        raise Breaker::CircuitOpenError
      end
    end

    private
    def tripped?
      @failure_count != 0
    end

    def half_open?(clock)
      tripped? && clock >= @retry_threshold
    end
  end
end
