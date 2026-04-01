import glot_backend/effect/auth/auth
import glot_backend/effect/core/core
import glot_backend/effect/docker_run/docker_run
import glot_backend/effect/error
import glot_backend/effect/runtime_types
import glot_backend/effect/snippet/snippet
import glot_backend/effect/transaction/transaction_command
import glot_backend/log
import gleam/dict

pub type Program(a) {
  Pure(a)
  Fail(error.Error)
  Impure(Effect(Program(a)))
}

pub type Handlers =
  runtime_types.Handlers

pub type TransactionCommand =
  transaction_command.TransactionCommand

pub type DbQueryName {
  CoreQueryName(core.CoreQueryName)
  AuthQueryName(auth.AuthQueryName)
}

pub type DbCommandName {
  CoreCommandName(core.CoreCommandName)
  AuthCommandName(auth.AuthCommandName)
  SnippetCommandName(snippet.SnippetCommandName)
}

pub type EffectName {
  NewTokenEffect
  SystemTimeEffect
  UuidV7Effect
  LogEffect
  DockerRunRequestEffect
  SendEmailEffect
  RunQueryEffect(DbQueryName)
  RunCommandEffect(DbCommandName)
  RunInTransactionEffect(List(DbCommandName))
}

pub type EffectTiming =
  #(EffectName, Int)

pub type State {
  State(
    effect_timings: List(EffectTiming),
    info_fields: log.Fields,
    warning_fields: log.Fields,
  )
}

pub type Effect(next) {
  CoreEffect(core.CoreEffect(next))
  AuthEffect(auth.AuthEffect(next))
  SnippetEffect(snippet.SnippetEffect(next))
  DockerRunEffect(docker_run.DockerRunEffect(next))
  TransactionEffect(
    List(Program(Nil)),
    fn(Result(Nil, error.DbTransactionError)) -> next,
  )
}

pub fn new_state() -> State {
  State(effect_timings: [], info_fields: log.new(), warning_fields: log.new())
}

pub fn add_effect_timings(
  state: State,
  effect_name: EffectName,
  duration_ns: Int,
) -> State {
  State(..state, effect_timings: [
    #(effect_name, duration_ns),
    ..state.effect_timings
  ])
}

pub fn add_info_fields(state: State, fields: log.Fields) -> State {
  State(..state, info_fields: dict.merge(state.info_fields, fields))
}

pub fn add_warning_fields(
  state: State,
  fields: log.Fields,
) -> State {
  State(..state, warning_fields: dict.merge(state.warning_fields, fields))
}
