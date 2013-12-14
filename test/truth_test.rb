require_relative 'test_helper'

class AcceptanceTest < MiniTest::Unit::TestCase
  DummyError = Class.new RuntimeError

  def test_goes_into_open_state_when_failure_threshold_reached
    breaker = Breaker::Circuit.new failure_threshold: 1, retry_timeout: 30
    assert breaker.closed?

    assert_raises DummyError do
      breaker.run do
        raise DummyError
      end
    end

    assert breaker.open?
    assert_raises Breaker::CircuitOpenError do
      breaker.run do
        1 + 1
      end
    end
  end

  def test_success_in_half_open_state_moves_breaker_into_closed
    clock = Time.now

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

  def test_failures_in_half_open_state_push_retry_timeout_back
    clock = Time.now

    breaker = Breaker::Circuit.new failure_threshold: 2, retry_timeout: 15
    breaker.open clock
    assert breaker.open?

    assert_raises DummyError do
      breaker.run clock + breaker.retry_timeout do
        raise DummyError
      end
    end

    assert_raises Breaker::CircuitOpenError do
      breaker.run clock + breaker.retry_timeout do
        assert false, "Block should not be run while in this state"
      end
    end

    assert_raises DummyError do
      breaker.run clock + breaker.retry_timeout * 2 do
        raise DummyError
      end
    end
  end

  private
  def assert_nothing_raised
    begin
      yield
    rescue => ex
      raise "Expected no errors, but #{ex} was raised"
    end
  end
end
