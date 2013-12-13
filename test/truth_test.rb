require_relative 'test_helper'

class AcceptanceTest < MiniTest::Unit::TestCase
  DummyError = Class.new RuntimeError

  def test_goes_into_open_state_when_failure_threshold_reached
    breaker = Breaker::Circuit.new failure_threshold: 3, retry_timeout: 30

    assert breaker.closed?

    3.times do
      begin
        breaker.run do
          raise DummyError
        end
      rescue DummyError
        # all good, this is intended
      end
    end

    assert_raises Breaker::CircuitOpenError do
      breaker.run do
        1 + 1
      end
    end

    assert breaker.open?
  end

  def test_success_in_half_open_state_moves_breaker_into_closed
    clock, service = Time.now, mock

    breaker = Breaker::Circuit.new failure_threshold: 2, retry_timeout: 15
    breaker.open clock
    assert breaker.open?

    assert_raises Breaker::CircuitOpenError do
      breaker.run clock do
         # nothing
      end
    end

    breaker.run clock + 15 do
      # do nothing, this works and flips the breaker back closed
    end

    assert breaker.closed?
  end
end
