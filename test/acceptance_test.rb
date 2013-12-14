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

    circuit = Breaker::Circuit.new store
    assert circuit.closed?

    assert_raises DummyError do
      circuit.run do
        raise DummyError
      end
    end

    assert circuit.open?
    assert_raises Breaker::CircuitOpenError do
      circuit.run do
        assert false, "Block should not run in this state"
      end
    end
  end

  def test_success_in_half_open_state_moves_circuit_into_closed
    store.failure_threshold = 2
    store.retry_timeout = 15

    clock = Time.now

    circuit = Breaker::Circuit.new store
    circuit.open clock
    assert circuit.open?

    assert_raises Breaker::CircuitOpenError do
      circuit.run clock do
         # nothing
      end
    end

    circuit.run clock + circuit.retry_timeout do
      # do nothing, this works and flips the circuit back closed
    end

    assert circuit.closed?
  end

  def test_failures_in_half_open_state_push_retry_timeout_back
    store.failure_threshold = 2
    store.retry_timeout = 15

    clock = Time.now

    circuit = Breaker::Circuit.new store, failure_threshold: 2, retry_timeout: 15
    circuit.open clock
    assert circuit.open?

    assert_raises DummyError do
      circuit.run clock + circuit.retry_timeout do
        raise DummyError
      end
    end

    assert_raises Breaker::CircuitOpenError do
      circuit.run clock + circuit.retry_timeout do
        assert false, "Block should not be run while in this state"
      end
    end

    assert_raises DummyError do
      circuit.run clock + circuit.retry_timeout * 2 do
        raise DummyError
      end
    end
  end

  def test_counts_timeouts_as_trips
    store.timeout = 0.01

    circuit = Breaker::Circuit.new store
    assert circuit.closed?

    assert_raises TimeoutError do
      circuit.run do
        sleep circuit.timeout * 2
      end
    end
  end
end
