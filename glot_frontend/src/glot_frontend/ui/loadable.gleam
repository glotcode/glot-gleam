import glot_core/loadable
import lustre/effect.{type Effect}

pub fn ensure_loaded(
  state: loadable.Loadable(data),
  load_effect: Effect(msg),
) -> #(loadable.Loadable(data), Effect(msg)) {
  case state {
    loadable.NotLoaded -> #(loadable.Loading, load_effect)
    loadable.Loading | loadable.Loaded(_) | loadable.LoadError(_) -> #(
      state,
      effect.none(),
    )
  }
}
