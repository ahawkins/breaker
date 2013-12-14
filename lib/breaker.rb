require "breaker/version"
require 'timeout'

module Breaker
  CircuitOpenError = Class.new RuntimeError

  class Circuit
    attr_accessor :store

    def initialize(store, options = {})
      @store = store
    end

    def open(clock = Time.now)
      store.failure_count = 1
      store.state = :open
      store.retry_threshold = clock + retry_timeout
    end

    def close
      store.failure_count = 0
      store.state = :closed
      store.retry_threshold = nil
    end

    def open?
      store.state == :open
    end

    def closed?
      store.state == :closed
    end

    def retry_timeout
      store.retry_timeout
    end

    def timeout
      store.timeout
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
          store.retry_threshold = clock + retry_timeout

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
      tripped? && clock >= store.retry_threshold
    end
  end
end
