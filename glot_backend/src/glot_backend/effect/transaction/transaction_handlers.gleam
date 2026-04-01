import glot_backend/context
import gleam/result
import gleam/string
import glot_backend/effect/handlers_builder
import glot_backend/effect/interpreter
import glot_backend/effect/error
import glot_backend/effect/runtime_types
import glot_backend/effect/types
import pog

pub fn run_in_transaction(
  ctx: context.Context,
  commands: List(types.Program(Nil)),
) -> Result(Nil, error.DbTransactionError) {
  pog.transaction(ctx.db, fn(tx) {
    let tx_context = context.Context(..ctx, db: tx)
    let tx_handlers = handlers_builder.from_context(
      tx_context,
      fn(programs) { run_in_transaction(tx_context, programs) },
    )
    execute_programs(tx_handlers, commands)
  })
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(err) {
    error.DbTransactionError(string.inspect(err))
  })
}

fn execute_programs(
  handlers: runtime_types.Handlers,
  programs: List(types.Program(Nil)),
) -> Result(Nil, error.Error) {
  case programs {
    [] -> Ok(Nil)
    [program, ..rest] -> {
      let #(result, _) = interpreter.run(program, handlers)
      use _ <- result.try(result)
      execute_programs(handlers, rest)
    }
  }
}
