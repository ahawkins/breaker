require "breaker/version"
require 'timeout'

module Breaker
  CircuitOpenError = Class.new RuntimeError

  class Circuit
    attr_accessor :store, :failure_threshold, :retry_timeout, :timeout

    def initialize(store, options = {})
      @store = store

      options.each_pair do |key, value|
        send "#{key}=", value
      end

      self.retry_timeout ||= 60
      self.failure_threshold ||= 10
      self.timeout ||= 5

      @retry_threshold = nil
    end

    def open(clock = Time.now)
      store.failure_count = 1
      store.state = :open
      @retry_threshold = clock + retry_timeout
    end

    def close
      store.failure_count = 0
      store.state = :closed
      @retry_threshold = nil
    end

    def open?
      store.state == :open
    end

    def closed?
      store.state == :closed
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
          store.failure_count = store.failure_count + 1
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
      store.failure_count != 0
    end

    def half_open?(clock)
      tripped? && clock >= @retry_threshold
    end
  end
end
