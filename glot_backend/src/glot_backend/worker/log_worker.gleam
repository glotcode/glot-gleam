import gleam/erlang/process
import gleam/json
import gleam/option.{type Option}
import gleam/otp/actor
import gleam/otp/supervision
import gleam/string
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
  GetCount(reply: process.Subject(Int))
}

type State {
  State(db: pog.Connection)
}

const call_timeout_ms = 100

pub fn start(name: process.Name(Message), db: pog.Connection) {
  actor.new(State(db: db))
  |> actor.named(name)
  |> actor.on_message(handle_message)
  |> actor.start
}

pub fn supervised(name: process.Name(Message), db: pog.Connection) {
  supervision.worker(fn() { start(name, db) })
}

pub fn get_count(subject: process.Subject(Message)) -> Int {
  process.call(subject, call_timeout_ms, GetCount)
}

fn handle_message(state: State, message: Message) -> actor.Next(State, Message) {
  case message {
    Insert(log_entry) -> {
      insert_api_log(state.db, log_entry)
      actor.continue(state)
    }
    GetCount(reply) -> {
      // `process.call` only reaches this point after earlier inserts in the
      // mailbox have been processed, so replying `0` acts as an idle barrier.
      process.send(reply, 0)
      actor.continue(state)
    }
  }
}

fn insert_api_log(db: pog.Connection, entry: ApiLogEntry) -> Nil {
  let query =
    sql.insert_api_log(
      id: uuid.to_bit_array(entry.id),
      request_id: uuid.to_bit_array(entry.request_id),
      created_at: entry.created_at,
      action: api_action.to_string(entry.action),
      body_bytes: entry.body_bytes,
      duration_ns: entry.duration_ns,
      ip: entry.ip,
      user_agent: entry.user_agent,
      info: entry.info
        |> dict_helpers.non_empty_dict
        |> option.map(log.encode_fields)
        |> option.map(json.to_string),
      warnings: entry.warnings
        |> dict_helpers.non_empty_dict
        |> option.map(log.encode_fields)
        |> option.map(json.to_string),
      debug: entry.debug
        |> dict_helpers.non_empty_dict
        |> option.map(log.encode_fields)
        |> option.map(json.to_string),
      error: entry.error
        |> option.map(encode_error)
        |> option.map(json.to_string),
      effects: entry.effects
        |> list_helpers.non_empty_list
        |> option.map(effect_trace.encode_effect_measurements)
        |> option.map(json.to_string),
    )

  let res = db_helpers.execute(db, query, fn(err) { string.inspect(err) })

  case res {
    Ok(_) -> Nil
    Error(err) -> wisp.log_error("Failed to insert log entry: " <> err)
  }
}

fn encode_error(err: error.Error) -> json.Json {
  json.object([
    #("message", json.string(error.to_string(err))),
  ])
}
