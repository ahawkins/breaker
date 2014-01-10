module Breaker
  module TestCases
    DummyError = Class.new RuntimeError

    def fuse
      flunk "Test must define a fuse class to use"
    end

    def repo
      flunk "Test must define a repo to use"
    end

    def fuse_name
      'test'
    end

    def setup
      Breaker.repo = repo
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
      fuse.retry_timeout = 15
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
      circuit = Breaker.circuit fuse_name

      assert_equal 1, Breaker.repo.count
      fuse = Breaker.repo.first

      assert_equal fuse_name, fuse.name
    end

    def test_circuit_factory_creates_new_fuses_with_sensible_defaults
      circuit = Breaker.circuit fuse_name

      assert_equal 1, Breaker.repo.count
      fuse = Breaker.repo.first

      assert_equal 10, fuse.failure_threshold
      assert_equal 60, fuse.retry_timeout
      assert_equal 5, fuse.timeout
    end

    def test_circuit_factory_updates_existing_fuses
      Breaker.circuit fuse_name
      assert_equal 1, Breaker.repo.count

      Breaker.circuit fuse_name, failure_threshold: 1,
        retry_timeout: 2, timeout: 3

      assert_equal 1, Breaker.repo.count
      fuse = Breaker.repo.first

      assert_equal 1, fuse.failure_threshold
      assert_equal 2, fuse.retry_timeout
      assert_equal 3, fuse.timeout
    end

    def test_circuit_breaker_factory_can_run_code_through_the_circuit
      assert_raises DummyError do
        Breaker.circuit fuse_name do
          raise DummyError
        end
      end
    end

    def test_breaker_query_methods
      circuit = Breaker.circuit fuse_name
      circuit.close

      assert Breaker.closed?(fuse_name)
      assert Breaker.up?(fuse_name)
      refute Breaker.open?(fuse_name)
      refute Breaker.down?(fuse_name)

      circuit.open

      assert Breaker.open?(fuse_name)
      assert Breaker.down?(fuse_name)
      refute Breaker.closed?(fuse_name)
      refute Breaker.up?(fuse_name)
    end
  end
end
