import gleam/erlang/process
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/otp/actor
import gleam/otp/supervision
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/helpers/db_helpers
import glot_backend/log
import glot_backend/sql
import glot_core/api_action.{type ApiAction}
import glot_core/helpers/dict_helpers
import glot_core/helpers/list_helpers
import pog
import wisp
import youid/uuid.{type Uuid}

pub type ApiLogEntry {
  ApiLogEntry(
    id: Uuid,
    request_id: Uuid,
    created_at: Timestamp,
    action: ApiAction,
    body_bytes: Int,
    duration_ns: Int,
    ip: Option(String),
    user_agent: Option(String),
    info: log.Fields,
    warnings: log.Fields,
    debug: log.Fields,
    error: Option(error.Error),
    effects: List(effect_trace.EffectMeasurement),
  )
}

pub type Message {
  Insert(ApiLogEntry)
  Tick
  Drain(reply: process.Subject(Nil))
}

type State {
  State(
    subject: process.Subject(Message),
    db: pog.Connection,
    pending_entries: List(ApiLogEntry),
    pending_count: Int,
    flush_scheduled: Bool,
  )
}

const call_timeout_ms = 5000

const flush_interval_ms = 5000

const max_batch_size = 100

const max_buffer_size = 1000

pub fn start(name: process.Name(Message), db: pog.Connection) {
  actor.new_with_initialiser(1000, fn(subject) {
    let initial_state =
      State(
        subject: subject,
        db: db,
        pending_entries: [],
        pending_count: 0,
        flush_scheduled: False,
      )
    let initialised = actor.initialised(initial_state)
    Ok(actor.returning(initialised, Nil))
  })
  |> actor.named(name)
  |> actor.on_message(handle_message)
  |> actor.start
}

pub fn supervised(name: process.Name(Message), db: pog.Connection) {
  supervision.worker(fn() { start(name, db) })
}

pub fn drain(subject: process.Subject(Message)) -> Nil {
  process.call(subject, call_timeout_ms, Drain)
}

fn handle_message(state: State, message: Message) -> actor.Next(State, Message) {
  case message {
    Insert(log_entry) -> {
      let state =
        state
        |> enqueue_entry(log_entry)
        |> schedule_flush_if_needed()

      case state.pending_count >= max_batch_size {
        True -> actor.continue(flush_entries_runtime(state))
        False -> actor.continue(state)
      }
    }
    Tick -> {
      let state = State(..state, flush_scheduled: False)
      actor.continue(flush_entries_runtime(state))
    }
    Drain(reply) -> {
      // `process.call` only reaches this point after earlier inserts in the
      // mailbox have been processed, so flushing here acts as an idle barrier.
      let state = flush_entries_for_shutdown(state)
      process.send(reply, Nil)
      actor.continue(state)
    }
  }
}

fn enqueue_entry(state: State, entry: ApiLogEntry) -> State {
  case state.pending_count >= max_buffer_size {
    True ->
      State(
        ..state,
        pending_entries: [entry, ..drop_oldest_entry(state.pending_entries)],
      )
    False ->
      State(
        ..state,
        pending_entries: [entry, ..state.pending_entries],
        pending_count: state.pending_count + 1,
      )
  }
}

fn drop_oldest_entry(entries: List(ApiLogEntry)) -> List(ApiLogEntry) {
  case list.reverse(entries) {
    [] -> []
    [_oldest, ..rest] -> list.reverse(rest)
  }
}

fn schedule_flush_if_needed(state: State) -> State {
  case state.pending_count > 0 && !state.flush_scheduled {
    True -> {
      let _ = process.send_after(state.subject, flush_interval_ms, Tick)
      State(..state, flush_scheduled: True)
    }
    False -> state
  }
}

fn flush_entries_runtime(state: State) -> State {
  case state.pending_entries {
    [] -> State(..state, flush_scheduled: False)
    pending_entries -> {
      case insert_api_logs(state.db, list.reverse(pending_entries)) {
        Ok(_) ->
          State(
            ..state,
            pending_entries: [],
            pending_count: 0,
            flush_scheduled: False,
          )
        Error(err) -> {
          wisp.log_error("Failed to insert log entry batch: " <> err)
          schedule_flush_if_needed(state)
        }
      }
    }
  }
}

fn flush_entries_for_shutdown(state: State) -> State {
  case state.pending_entries {
    [] -> State(..state, flush_scheduled: False)
    pending_entries -> {
      case insert_api_logs(state.db, list.reverse(pending_entries)) {
        Ok(_) -> {
          State(
            ..state,
            pending_entries: [],
            pending_count: 0,
            flush_scheduled: False,
          )
        }
        Error(err) -> {
          wisp.log_error("Failed to insert log entry batch during shutdown: " <> err)
          State(
            ..state,
            pending_entries: [],
            pending_count: 0,
            flush_scheduled: False,
          )
        }
      }
    }
  }
}

fn insert_api_logs(
  db: pog.Connection,
  entries: List(ApiLogEntry),
) -> Result(Nil, String) {
  let query =
    sql.insert_api_log(
      entries: json.array(entries, of: encode_log_entry) |> json.to_string,
    )

  let res = db_helpers.execute(db, query, fn(err) { string.inspect(err) })

  case res {
    Ok(_) -> Ok(Nil)
    Error(err) -> Error(err)
  }
}

fn encode_error(err: error.Error) -> json.Json {
  json.object([
    #("message", json.string(error.to_string(err))),
  ])
}

fn encode_log_entry(entry: ApiLogEntry) -> json.Json {
  json.object([
    #("id", json.string(uuid.to_string(entry.id))),
    #("request_id", json.string(uuid.to_string(entry.request_id))),
    #(
      "created_at",
      json.string(timestamp.to_rfc3339(entry.created_at, calendar.utc_offset)),
    ),
    #("action", json.string(api_action.to_string(entry.action))),
    #("body_bytes", json.int(entry.body_bytes)),
    #("duration_ns", json.int(entry.duration_ns)),
    #("ip", json.nullable(entry.ip, json.string)),
    #("user_agent", json.nullable(entry.user_agent, json.string)),
    #(
      "info",
      json.nullable(
        entry.info
          |> dict_helpers.non_empty_dict,
        log.encode_fields,
      ),
    ),
    #(
      "warnings",
      json.nullable(
        entry.warnings
          |> dict_helpers.non_empty_dict,
        log.encode_fields,
      ),
    ),
    #(
      "debug",
      json.nullable(
        entry.debug
          |> dict_helpers.non_empty_dict,
        log.encode_fields,
      ),
    ),
    #("error", json.nullable(entry.error, encode_error)),
    #(
      "effects",
      json.nullable(
        entry.effects
          |> list_helpers.non_empty_list,
        effect_trace.encode_effect_measurements,
      ),
    ),
  ])
}
