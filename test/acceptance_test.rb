require_relative 'test_helper'

class AcceptanceTest < MiniTest::Unit::TestCase
  include Breaker::TestCases

  InMemoryFuse = Struct.new :state, :failure_count, :retry_threshold,
    :failure_threshold, :retry_timeout, :timeout

  attr_reader :fuse, :repo

  def setup
    @repo = Breaker::InMemoryRepo.new
    @fuse = InMemoryFuse.new :closed, 0, nil, 3, 15, 10
    super
  end
end
