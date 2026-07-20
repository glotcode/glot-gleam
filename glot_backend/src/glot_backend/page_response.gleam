import gleam/option.{type Option}
import glot_backend/system/effect/effect_trace
import glot_backend/system/effect/error
import glot_backend/system/effect/log
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
