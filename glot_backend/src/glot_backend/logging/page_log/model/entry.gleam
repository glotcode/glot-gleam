import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import glot_backend/system/effect/effect_trace
import glot_backend/system/effect/error
import glot_backend/system/effect/log
import youid/uuid.{type Uuid}

pub type Entry {
  Entry(
    id: Uuid,
    request_id: Uuid,
    created_at: Timestamp,
    route: String,
    path: String,
    status_code: Int,
    render_mode: String,
    duration_ns: Int,
    ip: Option(String),
    user_agent: Option(String),
    referrer: Option(String),
    info: log.Fields,
    warnings: log.Fields,
    debug: log.Fields,
    error: Option(error.Error),
    effects: List(effect_trace.EffectMeasurement),
  )
}
