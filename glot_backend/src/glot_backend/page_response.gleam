import glot_backend/effect/effect_trace
import wisp

pub type PageResponse {
  PageResponse(
    response: wisp.Response,
    effects: List(effect_trace.EffectMeasurement),
  )
}
