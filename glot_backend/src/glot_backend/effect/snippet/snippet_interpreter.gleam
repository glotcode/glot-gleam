import glot_backend/effect/error
import glot_backend/effect/runtime_types
import glot_backend/effect/snippet/snippet
import glot_backend/effect/transaction/transaction_command
import glot_backend/effect/types
import glot_backend/erlang

pub fn run(
  effect: snippet.SnippetEffect(types.Program(a)),
  handlers: runtime_types.Handlers,
  state: types.State,
  continue: fn(types.Program(a), types.State) -> #(Result(a, error.Error), types.State),
  measure: fn(types.State, types.EffectName, Int) -> types.State,
) -> #(Result(a, error.Error), types.State) {
  case effect {
    snippet.RunCommand(command, next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.run_command(transaction_command.SnippetCommand(command))
      continue(
        next(result),
        measure(
          state,
          types.RunCommandEffect(
            types.SnippetCommandName(snippet.command_name(command)),
          ),
          started_at,
        ),
      )
    }
  }
}
