import gleam/result
import glot_backend/system/lifecycle/startup/migration_runner
import glot_backend/system/lifecycle/startup/ports/runner.{type Runner}
import pog

pub fn new(
  db: pog.Connection,
  migrations_directory: String,
  seeds_directory: String,
) -> Runner {
  runner.Runner(run: fn() {
    migration_runner.run_pending(db, migrations_directory)
    |> result.try(fn(applied_versions) {
      migration_runner.run_pending_seeds(db, seeds_directory)
      |> result.map(fn(applied_seeds) { #(applied_versions, applied_seeds) })
    })
  })
}
