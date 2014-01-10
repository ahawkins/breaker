require "breaker/version"
require 'timeout'

module Breaker
  CircuitOpenError = Class.new RuntimeError

  class << self
    def circuit(name, options = {})
      fuse = repo.upsert({
        name: name,
        failure_threshold: options.fetch(:failure_threshold, 10),
        retry_timeout: options.fetch(:retry_timeout, 60),
        timeout: options.fetch(:timeout, 5)
      })

      circuit = Circuit.new fuse

      if block_given?
        circuit.run do
          yield
        end
      end

      circuit
    end

    def closed?(name)
      circuit(name).closed?
    end
    alias up? closed?

    def open?(name)
      circuit(name).open?
    end
    alias down? open?

    def repo
      @repo
    end

    def repo=(repo)
      @repo = repo
    end
  end

  class Circuit
    attr_accessor :fuse

    def initialize(fuse, options = {})
      @fuse = fuse
    end

    def open(clock = Time.now)
      fuse.failure_count = 1
      fuse.state = :open
      fuse.retry_threshold = clock + retry_timeout
    end

    def close
      fuse.failure_count = 0
      fuse.state = :closed
      fuse.retry_threshold = nil
    end

    def ==(other)
      other.instance_of?(self.class) && fuse == other.fuse
    end

    def open?
      fuse.state == :open
    end
    alias down? open?

    def closed?
      fuse.state == :closed
    end
    alias up? closed?

    def retry_timeout
      fuse.retry_timeout
    end

    def failure_count
      fuse.failure_count
    end

    def failure_threshold
      fuse.failure_threshold
    end

    def timeout
      fuse.timeout
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
          fuse.failure_count = fuse.failure_count + 1
          fuse.retry_threshold = clock + retry_timeout

          open clock

          raise ex
        end
      else
        raise Breaker::CircuitOpenError
      end
    end

    private
    def tripped?
      fuse.failure_count != 0
    end

    def half_open?(clock)
      tripped? && clock >= fuse.retry_threshold
    end
  end
end

require_relative 'breaker/in_memory_repo'
require_relative 'breaker/test_cases'

Breaker.repo = Breaker::InMemoryRepo.new
