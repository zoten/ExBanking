# ExBanking

💰 Simple banking OTP application in Elixir language

[specification](https://github.com/coingaming/elixir-test)

## Elixir version

A `.tool-versions.recommended` is provided if you're an [asdf](https://github.com/asdf-vm/asdf) user, but should work with most versions

## Testing

### Test

``` elixir
mix test
```

### Coverage

``` elixir
mix coveralls
mix coveralls.html
```
### Dialyzer

``` elixir
mix dialyzer
```

### Generate documentation

``` elixir
mix docs
```

## Limitations

 * integers and users are limited by memory size. No assumption is done on it, nor
   particular error management for memory events
 * no rollback is implemented if for any reason besides application's logic (rate limiting, missing funds etc) transactional behaviours (e.g. `send` command) fails (e.g. the genserver is manually killed in a iex session)
 * there is still a race condition in getting a user's pid vs reserving its operation. They could be collapsed in the same `ets` row in `UserStore`, but this would mean most likely rewriting logic that belongs to `Registry` and be probably more error prone. For the scope of the exercise, it is considered that users mostly die gracefully (aka they don't die, otherwise other modifications to `UserStore` should be performed to handle hanging queue reservations)
 * for the same reason, `UserWorker` keeps its own balance instead of creating and `:ets.give_away` an `ets` table to an idle owner process (this would save the amount in case of `GenServer`'s restarts)
   * -> no supplementary service for `GenServer`'s crashes is implemented to recover state
 * is is allowed for a user to send money to himself. As long as he is happy :)

