import gleam/dict
import gleam/int
import glot_backend/effect/effect_model
import glot_backend/erlang
import glot_backend/log

pub type State {
  State(
    effect_measurements: List(effect_model.EffectMeasurement),
    info_fields: log.Fields,
    warning_fields: log.Fields,
  )
}

pub fn new_state() -> State {
  State(
    effect_measurements: [],
    info_fields: log.new(),
    warning_fields: log.new(),
  )
}

pub fn add_info_fields(state: State, fields: log.Fields) -> State {
  State(..state, info_fields: dict.merge(state.info_fields, fields))
}

pub fn add_warning_fields(state: State, fields: log.Fields) -> State {
  State(..state, warning_fields: dict.merge(state.warning_fields, fields))
}

pub fn add_effect_measurement(
  state: State,
  name: effect_model.EffectName,
  category: effect_model.EffectCategory,
  started_at_ns: Int,
) -> State {
  let duration_ns = int.max(erlang.perf_counter_ns() - started_at_ns, 0)

  State(..state, effect_measurements: [
    effect_model.EffectMeasurement(name:, category:, duration_ns:),
    ..state.effect_measurements
  ])
}
