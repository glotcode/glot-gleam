import glot_frontend/platform/timer
import glot_frontend/ui/delayed_loading
import lustre/effect.{type Effect}

pub fn start(
  state: delayed_loading.State,
  on_delay_elapsed: fn(Int) -> msg,
) -> #(delayed_loading.State, Effect(msg)) {
  let #(state, generation) = delayed_loading.begin(state)
  #(
    state,
    effect.from(fn(dispatch) {
      timer.schedule(delayed_loading.delay(), fn() {
        generation
        |> on_delay_elapsed
        |> dispatch
      })
    }),
  )
}
