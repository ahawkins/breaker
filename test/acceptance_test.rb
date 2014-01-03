require_relative 'test_helper'

class AcceptanceTest < MiniTest::Unit::TestCase
  DummyError = Class.new RuntimeError

  InMemoryFuse = Struct.new :state, :failure_count, :retry_threshold,
    :failure_threshold, :retry_timeout, :timeout

  attr_reader :fuse

  def setup
    @fuse = InMemoryFuse.new :closed, 0, nil, 3, 15, 10
  end

  def test_goes_into_open_state_when_failure_threshold_reached
    fuse.failure_threshold = 1
    fuse.retry_timeout = 30

    circuit = Breaker::Circuit.new fuse
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
    fuse.failure_threshold = 2
    fuse.retry_timeout = 15

    clock = Time.now

    circuit = Breaker::Circuit.new fuse
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
    fuse.failure_threshold = 2
    fuse.retry_timeout = 15

    clock = Time.now

    circuit = Breaker::Circuit.new fuse, failure_threshold: 2, retry_timeout: 15
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
    fuse.timeout = 0.01

    circuit = Breaker::Circuit.new fuse
    assert circuit.closed?

    assert_raises TimeoutError do
      circuit.run do
        sleep circuit.timeout * 2
      end
    end
  end

  def test_circuit_factory_persists_fuses
    circuit = Breaker.circuit 'test'

    assert_equal 1, Breaker.repo.count
    fuse = Breaker.repo.first

    assert_equal 'test', fuse.name
  end

  def test_circuit_factory_creates_new_fuses_with_sensible_defaults
    circuit = Breaker.circuit 'test'

    assert_equal 1, Breaker.repo.count
    fuse = Breaker.repo.first

    assert_equal 10, fuse.failure_threshold
    assert_equal 60, fuse.retry_timeout
    assert_equal 5, fuse.timeout
  end

  def test_circuit_factory_updates_existing_fuses
    Breaker.circuit 'test'
    assert_equal 1, Breaker.repo.count

    Breaker.circuit 'test', failure_threshold: 1,
      retry_timeout: 2, timeout: 3

    assert_equal 1, Breaker.repo.count
    fuse = Breaker.repo.first

    assert_equal 1, fuse.failure_threshold
    assert_equal 2, fuse.retry_timeout
    assert_equal 3, fuse.timeout
  end

  def test_circuit_breaker_factory_can_run_code_through_the_circuit
    assert_raises DummyError do
      Breaker.circuit 'test' do
        raise DummyError
      end
    end
  end

  def test_breaker_has_a_closed_query_method
    circuit = Breaker.circuit 'test'
    circuit.close
    assert Breaker.closed?('test')
    assert Breaker.up?('test')
    refute Breaker.open?('test')
    refute Breaker.down?('test')

    circuit.open
    assert Breaker.open?('test')
    assert Breaker.down?('test')
    refute Breaker.closed?('test')
    refute Breaker.up?('test')
  end
end
