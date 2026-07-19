import lustre/effect.{type Effect}

const delay_milliseconds = 1000

pub opaque type State {
  State(generation: Int, loading: Bool, visible: Bool)
}

pub fn idle() -> State {
  State(generation: 0, loading: False, visible: False)
}

pub fn start(
  state: State,
  on_delay_elapsed: fn(Int) -> msg,
) -> #(State, Effect(msg)) {
  let generation = state.generation + 1
  #(
    State(generation:, loading: True, visible: False),
    effect.from(fn(dispatch) {
      wait(delay_milliseconds, fn() {
        generation
        |> on_delay_elapsed
        |> dispatch
      })
    }),
  )
}

pub fn reveal(state: State, generation: Int) -> State {
  case state.loading && state.generation == generation {
    True -> State(..state, visible: True)
    False -> state
  }
}

pub fn finish(state: State) -> State {
  State(..state, loading: False, visible: False)
}

pub fn is_visible(state: State) -> Bool {
  state.loading && state.visible
}

@external(javascript, "./delayed_loading_ffi.mjs", "wait")
fn wait(milliseconds: Int, callback: fn() -> Nil) -> Nil
