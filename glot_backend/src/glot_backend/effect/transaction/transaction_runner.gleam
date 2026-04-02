import gleam/dict
import gleam/list
import gleam/string
import glot_backend/context
import glot_backend/effect/effect_model
import glot_backend/effect/error
import glot_backend/effect/handlers
import glot_backend/effect/interpreter
import glot_backend/effect/program_state
import pog

pub fn run_in_transaction(
  ctx: context.Context,
  sub_effects: List(effect_model.Program(Nil)),
) -> #(Result(Nil, error.DbTransactionError), program_state.State) {
  pog.transaction(ctx.db, fn(tx) {
    let tx_context = context.Context(..ctx, db: tx)
    let tx_handlers =
      handlers.from_context(tx_context, fn(programs) {
        run_in_transaction(tx_context, programs)
      })
    case execute_programs(tx_handlers, sub_effects) {
      #(Ok(_), state) -> Ok(state)
      #(Error(err), state) -> Error(#(err, state))
    }
  })
  |> collapse_transaction_result
}

fn execute_programs(
  handlers: handlers.Handlers,
  programs: List(effect_model.Program(Nil)),
) -> #(Result(Nil, error.Error), program_state.State) {
  case programs {
    [] -> #(Ok(Nil), program_state.new_state())
    [program, ..rest] -> {
      let #(result, state) = interpreter.run(program, handlers)
      case result {
        Ok(_) -> {
          let #(rest_result, rest_state) = execute_programs(handlers, rest)
          #(rest_result, combine_states(state, rest_state))
        }
        Error(err) -> #(Error(err), state)
      }
    }
  }
}

fn combine_states(
  first: program_state.State,
  second: program_state.State,
) -> program_state.State {
  program_state.State(
    effect_measurements: list.append(
      first.effect_measurements,
      second.effect_measurements,
    ),
    info_fields: dict.merge(first.info_fields, second.info_fields),
    warning_fields: dict.merge(first.warning_fields, second.warning_fields),
  )
}

fn collapse_transaction_result(
  result: Result(
    program_state.State,
    pog.TransactionError(#(error.Error, program_state.State)),
  ),
) -> #(Result(Nil, error.DbTransactionError), program_state.State) {
  case result {
    Ok(state) -> #(Ok(Nil), state)
    Error(pog.TransactionRolledBack(#(err, state))) -> #(
      Error(error.DbTransactionError(string.inspect(err))),
      state,
    )
    Error(err) -> #(
      Error(error.DbTransactionError(string.inspect(err))),
      program_state.new_state(),
    )
  }
}
