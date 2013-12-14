require_relative 'test_helper'

class AcceptanceTest < MiniTest::Unit::TestCase
  DummyError = Class.new RuntimeError

  InMemoryStore = Struct.new :state, :failure_count, :retry_threshold,
    :failure_threshold, :retry_timeout, :timeout

  attr_reader :store

  def setup
    @store = InMemoryStore.new :closed, 0, nil, 3, 15, 10
  end

  def test_goes_into_open_state_when_failure_threshold_reached
    store.failure_threshold = 1
    store.retry_timeout = 30

    breaker = Breaker::Circuit.new store
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
    store.failure_threshold = 2
    store.retry_timeout = 15

    clock = Time.now

    breaker = Breaker::Circuit.new store
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
    store.failure_threshold = 2
    store.retry_timeout = 15

    clock = Time.now

    breaker = Breaker::Circuit.new store, failure_threshold: 2, retry_timeout: 15
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
    store.timeout = 0.01

    breaker = Breaker::Circuit.new store
    assert breaker.closed?

    assert_raises TimeoutError do
      breaker.run do
        sleep breaker.timeout * 2
      end
    end
  end
end
