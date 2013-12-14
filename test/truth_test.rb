require_relative 'test_helper'

class AcceptanceTest < MiniTest::Unit::TestCase
  DummyError = Class.new RuntimeError

  def test_has_sensible_defaults
    breaker = Breaker::Circuit.new

    assert_equal 60, breaker.retry_timeout
    assert_equal 10, breaker.failure_threshold
    assert_equal 5, breaker.timeout
  end

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
        assert false, "Block should not run in this state"
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

    breaker.run clock + breaker.retry_timeout do
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

  def test_counts_timeouts_as_trips
    breaker = Breaker::Circuit.new failure_threshold: 2, retry_timeout: 15, timeout: 0.01
    assert breaker.closed?

    assert_raises TimeoutError do
      breaker.run do
        sleep breaker.timeout * 2
      end
    end
  end
end
