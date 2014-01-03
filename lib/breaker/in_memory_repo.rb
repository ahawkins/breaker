module Breaker
  class InMemoryRepo
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
      fuse = Breaker::Fuse.new

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
