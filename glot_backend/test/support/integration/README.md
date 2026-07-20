# Integration test support

These tests run domain programs through the production effect interpreter while
replacing external systems and PostgreSQL with deterministic in-memory adapters.

## Structure

- `model.gleam` defines `TestState`, the complete in-memory state used by the
  adapters.
- `fixture.gleam` creates common domain objects and initial state. Prefer adding
  reusable domain data here instead of rebuilding it in individual tests.
- `adapter/` implements individual database and system ports. Adapter defaults
  are strict: an undeclared call fails with `unexpected test port call`.
- `adapter/service_ports.gleam` is the composition root. Start with `defaults`
  and opt into only the adapters required by the feature.
- `profile/` contains feature-specific port compositions and a small runner for
  each feature.
- `runner.gleam` owns the effect runtime and the lifecycle of the in-memory
  state actor.

## Writing a feature test

Import the feature profile and run the program with a fixture:

```gleam
let fixture = fixture.integration_fixture(
  next_uuids: [],
  jobs: [],
  account_delete_job_id: option.None,
)

let #(result, final_state) =
  snippet_profile.run_test_program(program, fixture.ctx, fixture.state)
```

Assert both the returned result and any observable changes in `final_state`.
Tests should use the narrowest existing profile rather than the low-level runner.

## Adding a feature

1. Add the feature's state fields and reusable values to `model.gleam` and
   `fixture.gleam` when necessary.
2. Add focused store helpers under `store/`.
3. Add a strict default and an in-memory implementation under `adapter/`.
4. Add a `with_<feature>` composer to `adapter/service_ports.gleam`.
5. Add a feature profile that composes only its required dependencies.
6. Add the profile to `profile/contract_test.gleam`. The contract must prove
   that declared ports work and undeclared ports fail.

The in-memory transaction adapter snapshots all of `TestState`. Successful
callbacks commit state and UUID consumption; failed callbacks restore the full
snapshot. PostgreSQL adapter integration tests are intentionally separate from
this test layer.
