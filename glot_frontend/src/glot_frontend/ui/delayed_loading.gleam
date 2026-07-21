const delay_milliseconds = 1000

pub opaque type State {
  State(generation: Int, loading: Bool, visible: Bool)
}

pub fn idle() -> State {
  State(generation: 0, loading: False, visible: False)
}

/// Start loading without choosing an effect implementation. Feature-owned
/// managed effect algebras use the returned generation to schedule a message.
pub fn begin(state: State) -> #(State, Int) {
  let generation = state.generation + 1
  #(State(generation:, loading: True, visible: False), generation)
}

pub fn delay() -> Int {
  delay_milliseconds
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
