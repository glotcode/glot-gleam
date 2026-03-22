import gleam/erlang/process
import gleam/option.{type Option}
import gleam/otp/actor
import gleam/otp/supervision
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_backend/db_helpers
import glot_backend/sql
import pog
import youid/uuid.{type Uuid}
import wisp

pub type LogEntry {
  LogEntry(
    id: Uuid,
    created_at: Timestamp,
    action: String,
    duration_ns: Int,
    user_agent: Option(String),
    error: Option(String),
    fields: String,
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
      insert_log_entry(state.db, log_entry)
      actor.continue(state)
    }
  }
}

fn insert_log_entry(db: pog.Connection, entry: LogEntry) -> Nil {
  let LogEntry(
    id: id,
    created_at: created_at,
    action: action,
    duration_ns: duration_ns,
    user_agent: user_agent,
    error: error,
    fields: fields,
    effects: effects,
  ) = entry

  case db_helpers.execute(
    db,
    sql.insert_log_entry(
      id: uuid.to_bit_array(id),
      created_at: created_at,
      action: action,
      duration_ns: duration_ns,
      user_agent: user_agent,
      error: error,
      fields: fields,
      effects: effects,
    ),
    fn(err) { string.inspect(err) },
  ) {
    Ok(_) -> Nil
    Error(err) -> wisp.log_error("Failed to insert log entry: " <> err)
  }
}
