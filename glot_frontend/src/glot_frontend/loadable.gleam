import gleam/option
import lustre/effect.{type Effect, none}

pub type Loadable(data) {
  NotLoaded
  Loading
  Loaded(data)
  LoadError(String)
}

pub fn fold(
  state: Loadable(data),
  not_loaded: result,
  loading: result,
  loaded: fn(data) -> result,
  failed: fn(String) -> result,
) -> result {
  case state {
    NotLoaded -> not_loaded
    Loading -> loading
    Loaded(data) -> loaded(data)
    LoadError(message) -> failed(message)
  }
}

pub fn ensure_loaded(
  state: Loadable(data),
  load_effect: Effect(msg),
) -> #(Loadable(data), Effect(msg)) {
  case state {
    NotLoaded -> #(Loading, load_effect)
    Loading | Loaded(_) | LoadError(_) -> #(state, none())
  }
}

pub fn to_option(state: Loadable(data)) -> option.Option(data) {
  case state {
    Loaded(data) -> option.Some(data)
    NotLoaded | Loading | LoadError(_) -> option.None
  }
}

pub fn is_loading(state: Loadable(data)) -> Bool {
  case state {
    Loading -> True
    NotLoaded | Loaded(_) | LoadError(_) -> False
  }
}
