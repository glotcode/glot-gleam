import gleam/dict
import gleam/int
import gleam/json
import gleam/list
import glot_backend/effect/effect_model
import glot_backend/erlang
import glot_backend/log

pub type EffectTiming {
  EffectTiming(
    name: effect_model.EffectName,
    category: effect_model.EffectCategory,
    duration_ns: Int,
  )
}

pub type State {
  State(
    effect_timings: List(EffectTiming),
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
  effect_category: effect_model.EffectCategory,
  duration_ns: Int,
) -> State {
  State(..state, effect_timings: [
    EffectTiming(
      name: effect_name,
      category: effect_category,
      duration_ns: duration_ns,
    ),
    ..state.effect_timings
  ])
}

pub fn add_info_fields(state: State, fields: log.Fields) -> State {
  State(..state, info_fields: dict.merge(state.info_fields, fields))
}

pub fn add_warning_fields(state: State, fields: log.Fields) -> State {
  State(..state, warning_fields: dict.merge(state.warning_fields, fields))
}

pub fn measure_effect(
  state: State,
  effect_name: effect_model.EffectName,
  effect_category: effect_model.EffectCategory,
  started_at_ns: Int,
) -> State {
  let elapsed_ns = erlang.perf_counter_ns() - started_at_ns
  let safe_elapsed_ns = int.max(elapsed_ns, 0)
  add_effect_timings(state, effect_name, effect_category, safe_elapsed_ns)
}

pub fn encode_effect_timings(effects: List(EffectTiming)) -> json.Json {
  json.object([
    #("effects", json.array(effects, encode_effect_timing)),
    #(
      "summary",
      json.object([
        #("count", json.int(list.length(effects))),
        #(
          "duration_ns",
          json.int(
            list.fold(effects, 0, fn(acc, effect_timing) {
              acc + effect_timing.duration_ns
            }),
          ),
        ),
      ]),
    ),
  ])
}

pub fn encode_effect_timing(effect_timing: EffectTiming) -> json.Json {
  let effect_name = effect_timing.name
  let duration_ns = effect_timing.duration_ns
  let effect_category =
    effect_model.effect_category_to_string(effect_timing.category)
  case effect_name {
    effect_model.RunInTransactionEffectName(commands) ->
      json.object([
        #("category", json.string(effect_category)),
        #(
          "family",
          json.string(effect_model.effect_name_to_family(effect_name)),
        ),
        #("name", json.string(effect_model.effect_name_to_string(effect_name))),
        #(
          "commands",
          json.array(
            list.map(commands, effect_model.effect_name_to_string),
            json.string,
          ),
        ),
        #("duration_ns", json.int(duration_ns)),
      ])
    _ ->
      json.object([
        #("category", json.string(effect_category)),
        #(
          "family",
          json.string(effect_model.effect_name_to_family(effect_name)),
        ),
        #("name", json.string(effect_model.effect_name_to_string(effect_name))),
        #("duration_ns", json.int(duration_ns)),
      ])
  }
}
