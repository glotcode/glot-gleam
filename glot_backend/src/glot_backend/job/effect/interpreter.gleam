import glot_backend/job/effect/algebra
import glot_backend/job/effect/job/interpreter as job_interpreter
import glot_backend/job/effect/log/interpreter as log_interpreter
import glot_backend/job/effect/periodic/interpreter as periodic_interpreter
import glot_backend/job/effect/type_policy/interpreter as type_policy_interpreter
import glot_backend/job/ports.{type Ports}
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
    algebra.Job(effect) ->
      job_interpreter.run(effect, ports.jobs, state, continue)
    algebra.Log(effect) ->
      log_interpreter.run(effect, ports.logs, state, continue)
    algebra.Periodic(effect) ->
      periodic_interpreter.run(effect, ports.periodic, state, continue)
    algebra.TypePolicy(effect) ->
      type_policy_interpreter.run(effect, ports.type_policies, state, continue)
  }
}
