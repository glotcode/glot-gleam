import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_backend/system/effect/effect_trace
import glot_backend/system/effect/error
import glot_backend/system/effect/log
import glot_core/job/job_model
import youid/uuid.{type Uuid}

pub type LogEntry {
  LogEntry(
    id: Uuid,
    request_id: option.Option(Uuid),
    job_id: Uuid,
    job_type: job_model.JobType,
    attempt: Int,
    created_at: Timestamp,
    duration_ns: Int,
    info: log.Fields,
    warnings: log.Fields,
    debug: log.Fields,
    error: option.Option(error.Error),
    effects: List(effect_trace.EffectMeasurement),
  )
}
