import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import glot_core/language.{type Language}
import youid/uuid.{type Uuid}

pub type RunOutcome {
  RunSucceeded
  RunFailed
}

pub fn run_outcome_to_string(outcome: RunOutcome) -> String {
  case outcome {
    RunSucceeded -> "succeeded"
    RunFailed -> "failed"
  }
}

pub type RunLog {
  RunLog(
    id: Uuid,
    request_id: Uuid,
    created_at: Timestamp,
    session_id: Option(Uuid),
    user_id: Option(Uuid),
    language: Language,
    outcome: RunOutcome,
    duration_ns: Option(Int),
    failure_message: Option(String),
  )
}
