require_relative 'test_helper'

class AcceptanceTest < MiniTest::Unit::TestCase
  DummyError = Class.new RuntimeError

  def test_goes_into_open_state_when_failure_threshold_reached
    breaker = Breaker::Circuit.new failure_threshold: 3

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
end
