import glot_frontend/api/public as public_api
import glot_frontend/platform/ssr_data
import glot_frontend/platform/timer
import glot_frontend/public/snippets/ports
import lustre/effect

pub fn new() -> ports.Ports(msg) {
  ports.Ports(
    load_ssr: fn(complete) {
      effect.from(fn(dispatch) { dispatch(complete(ssr_data.take())) })
    },
    list_public_snippets: public_api.list_public_snippets,
    schedule: fn(milliseconds, msg) {
      effect.from(fn(dispatch) {
        timer.schedule(milliseconds, fn() { dispatch(msg) })
      })
    },
  )
}
