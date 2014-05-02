module Breaker
  module TestCases
    DummyError = Class.new RuntimeError

    def repo
      flunk "Test must define a repo to use"
    end

    def setup
      Breaker.repo = repo
    end

    def test_new_fuses_start_off_clean
      circuit = Breaker.circuit 'test'

      assert circuit.closed?, "New circuits should be closed"
      assert_equal 0, circuit.failure_count
    end

    def test_goes_into_open_state_when_failure_threshold_reached
      circuit = Breaker.circuit 'test', failure_threshold: 5, retry_timeout: 30

      assert circuit.closed?

      circuit.failure_threshold.times do
        begin
          circuit.run do
            raise DummyError
          end
        rescue DummyError ; end
      end

      assert_equal circuit.failure_count, circuit.failure_threshold
      refute circuit.open?

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
      clock = Time.now
      circuit = Breaker.circuit 'test', failure_threshold: 2, retry_timeout: 15

      (circuit.failure_threshold + 1).times do
        begin
          circuit.run clock do
            raise DummyError
          end
        rescue DummyError ; end
      end

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
      clock = Time.now
      circuit = Breaker.circuit 'test', failure_threshold: 1, retry_timeout: 15

      (circuit.failure_threshold + 1).times do
        begin
          circuit.run clock do
            raise DummyError
          end
        rescue DummyError ; end
      end

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
      circuit = Breaker.circuit 'test', retry_timeout: 15, timeout: 0.01
      assert circuit.closed?

      assert_raises TimeoutError do
        circuit.run do
          sleep circuit.timeout * 2
        end
      end
    end

    def test_circuit_factory_persists_fuses
      circuit_a = Breaker.circuit 'test'
      circuit_b = Breaker.circuit 'test'

      assert_equal circuit_a, circuit_b, "Multiple calls to `circuit` should return the same circuit"

      assert_equal 1, Breaker.repo.count
      fuse = Breaker.repo.first

      assert_equal 'test', fuse.name
    end

    def test_circuit_factory_creates_new_fuses_with_sensible_defaults
      circuit = Breaker.circuit 'test'

      assert_equal 1, Breaker.repo.count
      fuse = Breaker.repo.first

      assert_equal 10, fuse.failure_threshold, "Failure Theshold should have a default"
      assert_equal 60, fuse.retry_timeout, "Retry timeout should have a default"
      assert_equal 5, fuse.timeout, "Timeout should have a default"
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

    def test_breaker_query_methods
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
end
