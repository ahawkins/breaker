module Breaker
  class InMemoryRepo
    Fuse = Struct.new :name, :state, :failure_threshold, :retry_timeout, :timeout, :failure_count, :retry_threshold do
      def initialize(*args)
        super
        self.state = :closed if state.nil?
        self.failure_count = 0 if failure_count.nil?
      end

      def ==(other)
        other.instance_of?(self.class) && name == other.name
      end
    end

    attr_reader :store

    def initialize
      @store = []
    end

    def upsert(attributes)
      existing = named attributes.fetch(:name)
      if existing
        update existing, attributes
      else
        create attributes
      end
    end

    def count
      store.length
    end

    def first
      store.first
    end

    def named(name)
      store.find { |fuse| fuse.name == name }
    end

    def create(attributes)
      fuse = Fuse.new

      attributes.each_pair do |key, value|
        fuse.send "#{key}=", value
      end

      store << fuse

      fuse
    end

    def update(existing, attributes)
      existing

      attributes.each_pair do |key, value|
        existing.send "#{key}=", value
      end

      existing
    end
  end
end
