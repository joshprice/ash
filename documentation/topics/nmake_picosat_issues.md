# Troubleshooting nmake/picosat compilation errors

The default implementation of the [Sat Solver](https://en.wikipedia.org/wiki/Boolean_satisfiability_problem) that is used under the hood in Ash uses [picosat_elixir](https://github.com/bitwalker/picosat_elixir). Picosat uses a NIF to bind to an extremely fast C implementation. However, this can cause some problems depending on your set up. In some cases it could be completely impossible to get it set up, depending on OS/constraints on your infrastructure, e.g if you're deploying on containers that don't allow you to set this kind of thing up for whatever reason.

## Debugging

### Environment Variables

First, take a look at `LDFLAGS` and `LD_LIBRARY_PATH` environment variables. If those are already set in your configuration, you may need to update them to include the correct paths, or just don't set those variables, and picosat_elixir should discover the correct paths automatically.

### Ensuring you have the appropriate packages installed

* You may need to install the  `erlang-dev` package, depending on your os and method of installing erlang.
* You may need to install the `build-essential` package for linux, or the `build-base` package if you are using alpine.

## Last resort

As a last resort, you can switch to a native elixir implementation of the sat solver. This implementation isn't used by many people, but it *is* run through the same test suite. If you opt to use the native elixir implementation, *please* be extra dilligent when testing your authorization use cases (really, you should just do that anyway). Simply remove the `{:picosat_elixir, ...}` dependency, and replace it with:

```elixir
{:csp, "~> 0.1.0"},
```
