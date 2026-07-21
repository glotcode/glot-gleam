import glot_frontend/admin/request_generation.{type Generation}

pub opaque type State {
  State(generation: Generation)
}

pub fn initial() -> State {
  State(request_generation.initial())
}

pub fn begin(state: State) -> #(State, Generation) {
  let generation = request_generation.next(state.generation)
  #(State(generation), generation)
}

pub fn generation(state: State) -> Generation {
  state.generation
}
