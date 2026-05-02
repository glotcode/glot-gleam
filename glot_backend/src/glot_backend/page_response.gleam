import gleam/option.{type Option}
import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/log
import wisp

pub type PageResponse {
  PageResponse(
    response: wisp.Response,
    status_code: Int,
    render_mode: String,
    effects: List(effect_trace.EffectMeasurement),
    info: log.Fields,
    warnings: log.Fields,
    debug: log.Fields,
    error: Option(error.Error),
  )
}
