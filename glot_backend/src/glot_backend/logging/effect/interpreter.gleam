import glot_backend/logging/api_log/effect/interpreter as api_log_interpreter
import glot_backend/logging/effect/algebra
import glot_backend/logging/page_log/effect/interpreter as page_log_interpreter
import glot_backend/logging/pageview/effect/interpreter as pageview_interpreter
import glot_backend/logging/ports.{type Ports}
import glot_backend/logging/run_log/effect/interpreter as run_log_interpreter
import glot_backend/system/effect/error
import glot_backend/system/effect/program_state

pub fn run(
  effect: algebra.Effect(next_program),
  ports: Ports,
  state: program_state.State,
  continue: fn(next_program, program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    algebra.ApiLog(effect) ->
      api_log_interpreter.run(effect, ports.api_log, state, continue)
    algebra.PageLog(effect) ->
      page_log_interpreter.run(effect, ports.page_log, state, continue)
    algebra.Pageview(effect) ->
      pageview_interpreter.run(effect, ports.pageview, state, continue)
    algebra.RunLog(effect) ->
      run_log_interpreter.run(effect, ports.run_log, state, continue)
  }
}
