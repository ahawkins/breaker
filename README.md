# Breaker

Circuit Breakers for well designed applications.

## Installation

Add this line to your application's Gemfile:

    gem 'breaker'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install breaker

## Circuit Breaker Pattern

The circuit breaker pattern is described in the (wonderful) book
[Release It](http://pragprog.com/book/mnee/release-it) by Michael T.
Nygard. A circuit breaker in programming terms is modeled after a
circuit breaker in the real world. A circuit breaker protects the
larger system from failures in other systems. They are especially
useful for protecting an application from finnicky remote systems.

The circuit is a state machine. It has three states: open, closed, and
half-open. The circuit starts off in `open` state--normal operation.
If the operation failures N times (the failure threshold) the circuit
moves to `closed`. Calls in the `closed` state will immediate fail and
raise an exception. After a specified time period has passed (retry
timeout) the circuit moves into `half-open`. Calls happen normally. If
a call fails the state moves to `open`. If the call suceeds it moves
to `open`. All calls are capped with a timeout. If a timeout occurs
that counts as a failure.

## Usage

Most interaction should go through `Breaker.circuit`. This is a
factory method that creates `Breaker::Circuit` objects. It requires
one argument: the name. It also takes an `options` hash for
customizing the circuit. Thirdly it takes a block to run inside the
circuit. Here are some examples:

```ruby
# Simplest example: protect some code with a circuit breaker
Breaker.circuit 'twitter' do
  Tweet.post 'Oh Hai'
end
```

`Breaker.circuit` is an upsert opertion. It will create or update an
existing circuit. Pass the options hash to customize the circuit's
behavior.

```ruby
circuit = Breaker.circuit 'twitter', timeout: 5
circuit.run do
  Tweet.post 'Oh Hai'
end
```

`Breaker.circuit` returns `Breaker::Circuit` instances which can be
saved for later. There use depends no how persistence works.

## Persistence

Circuit breakers are only really useful in a large system (perhaps
distributed). Some information must be shared acrosss subsystems. Say
there are 5 different services in the system. Each is
talking to 2 different systems protected by circuit breakers. Either
of the systems go down. It's natural that the failure should propogate
through the system so that each service knows the shared ones are
down. This is where state and persistence come into play.

The breaker gems bundles a simple in memory repository. This is
process specific. If you need to share state across multiple processes
then you must write your own repository.

The repository manages fueses (in the eletrical sense). A fuse
maintains state. The repository must implement one method: `upsert`
which creates or updates a fuse given by name. The repistory can
return some sort of persistent fuse where writer methods write to
persistent storage.

Refer to `lib/breaker/in_memory_repo.rb` for an example. The class is
very simple.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
