import gleam/dict
import gleam/int
import glot_backend/effect/effect_model
import glot_backend/erlang
import glot_backend/log

pub type State {
  State(
    effect_timings: List(effect_model.EffectTiming),
    info_fields: log.Fields,
    warning_fields: log.Fields,
  )
}

pub fn new_state() -> State {
  State(effect_timings: [], info_fields: log.new(), warning_fields: log.new())
}

pub fn add_effect_timings(
  state: State,
  effect_name: effect_model.EffectName,
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

pub fn measure_effect(
  state: State,
  effect_name: effect_model.EffectName,
  started_at_ns: Int,
) -> State {
  let elapsed_ns = erlang.perf_counter_ns() - started_at_ns
  let safe_elapsed_ns = int.max(elapsed_ns, 0)
  add_effect_timings(state, effect_name, safe_elapsed_ns)
}
