import gleam/erlang/process
import gleam/option.{type Option}
import gleam/otp/actor
import gleam/otp/supervision
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_backend/db_helpers
import glot_backend/sql
import pog
import wisp
import youid/uuid.{type Uuid}

pub type LogEntry {
  LogEntry(
    id: Uuid,
    request_id: Uuid,
    created_at: Timestamp,
    action: String,
    body_bytes: Int,
    duration_ns: Int,
    ip: Option(String),
    user_agent: Option(String),
    error: Option(String),
    data: String,
    effects: String,
  )
}

pub type Message {
  Insert(LogEntry)
}

type State {
  State(db: pog.Connection)
}

pub fn start(name: process.Name(Message), db: pog.Connection) {
  actor.new(State(db: db))
  |> actor.named(name)
  |> actor.on_message(handle_message)
  |> actor.start
}

pub fn supervised(name: process.Name(Message), db: pog.Connection) {
  supervision.worker(fn() { start(name, db) })
}

fn handle_message(state: State, message: Message) -> actor.Next(State, Message) {
  case message {
    Insert(log_entry) -> {
      insert_api_log(state.db, log_entry)
      actor.continue(state)
    }
  }
}

fn insert_api_log(db: pog.Connection, entry: LogEntry) -> Nil {
  let query =
    sql.insert_api_log(
      id: uuid.to_bit_array(entry.id),
      request_id: uuid.to_bit_array(entry.request_id),
      created_at: entry.created_at,
      action: entry.action,
      body_bytes: entry.body_bytes,
      duration_ns: entry.duration_ns,
      ip: entry.ip,
      user_agent: entry.user_agent,
      error: entry.error,
      data: entry.data,
      effects: entry.effects,
    )

  let res = db_helpers.execute(db, query, fn(err) { string.inspect(err) })

  case res {
    Ok(_) -> Nil
    Error(err) -> wisp.log_error("Failed to insert log entry: " <> err)
  }
}
