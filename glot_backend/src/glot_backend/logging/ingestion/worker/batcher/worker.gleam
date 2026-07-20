import gleam/erlang/process
import gleam/list
import gleam/otp/actor
import gleam/otp/supervision
import glot_backend/logging/api_log/model/entry as api_log_entry
import glot_backend/logging/ingestion/model/batch
import glot_backend/logging/ingestion/model/config as logging_config
import glot_backend/logging/page_log/model/entry as page_log_entry
import glot_backend/logging/pageview/model/entry as pageview_entry

pub type Message {
  InsertApi(api_log_entry.Entry)
  InsertPage(page_log_entry.Entry)
  InsertPageview(pageview_entry.Entry)
  RefreshConfig
  Tick
  Drain(reply: process.Subject(Nil))
}

pub type Deps {
  Deps(
    load_config: fn() -> Result(logging_config.Config, String),
    insert_batch: fn(List(batch.Entry)) -> Result(Nil, String),
    log_error: fn(String) -> Nil,
  )
}

type State {
  State(
    subject: process.Subject(Message),
    deps: Deps,
    config: logging_config.Config,
    pending_entries: List(batch.Entry),
    pending_count: Int,
    flush_scheduled: Bool,
  )
}

const call_timeout_ms = 5000

pub fn start(name: process.Name(Message), deps: Deps) {
  actor.new_with_initialiser(1000, fn(subject) {
    let initial_state =
      State(
        subject: subject,
        deps: deps,
        config: logging_config.default(),
        pending_entries: [],
        pending_count: 0,
        flush_scheduled: False,
      )
    let _ = process.send(subject, RefreshConfig)
    let initialised = actor.initialised(initial_state)
    Ok(actor.returning(initialised, Nil))
  })
  |> actor.named(name)
  |> actor.on_message(handle_message)
  |> actor.start
}

pub fn supervised(name: process.Name(Message), deps: Deps) {
  supervision.worker(fn() { start(name, deps) })
}

pub fn drain(subject: process.Subject(Message)) -> Nil {
  process.call(subject, call_timeout_ms, Drain)
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    InsertApi(log_entry) -> {
      let state =
        state
        |> enqueue_entry(batch.Api(log_entry))
        |> schedule_flush_if_needed()

      case reached_max_batch_size(state) {
        True -> actor.continue(flush_entries_runtime(state))
        False -> actor.continue(state)
      }
    }
    InsertPage(log_entry) -> {
      let state =
        state
        |> enqueue_entry(batch.Page(log_entry))
        |> schedule_flush_if_needed()

      case reached_max_batch_size(state) {
        True -> actor.continue(flush_entries_runtime(state))
        False -> actor.continue(state)
      }
    }
    InsertPageview(log_entry) -> {
      let state =
        state
        |> enqueue_entry(batch.Pageview(log_entry))
        |> schedule_flush_if_needed()

      case reached_max_batch_size(state) {
        True -> actor.continue(flush_entries_runtime(state))
        False -> actor.continue(state)
      }
    }
    RefreshConfig -> actor.continue(refresh_config(state))
    Tick -> {
      let state = refresh_config(state)
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

fn enqueue_entry(state: State, entry: batch.Entry) -> State {
  case state.pending_count >= state.config.max_buffer_size {
    True ->
      State(..state, pending_entries: [
        entry,
        ..drop_oldest_entry(state.pending_entries)
      ])
    False ->
      State(
        ..state,
        pending_entries: [entry, ..state.pending_entries],
        pending_count: state.pending_count + 1,
      )
  }
}

fn reached_max_batch_size(state: State) -> Bool {
  state.pending_count >= state.config.max_batch_size
}

fn drop_oldest_entry(entries: List(batch.Entry)) -> List(batch.Entry) {
  case list.reverse(entries) {
    [] -> []
    [_oldest, ..rest] -> list.reverse(rest)
  }
}

fn schedule_flush_if_needed(state: State) -> State {
  case state.pending_count > 0 && !state.flush_scheduled {
    True -> {
      let _ =
        process.send_after(state.subject, state.config.flush_interval_ms, Tick)
      State(..state, flush_scheduled: True)
    }
    False -> state
  }
}

fn refresh_config(state: State) -> State {
  case state.deps.load_config() {
    Ok(config) -> State(..state, config: config)
    Error(err) -> {
      state.deps.log_error("Failed to refresh log worker config: " <> err)
      state
    }
  }
}

fn flush_entries_runtime(state: State) -> State {
  case state.pending_entries {
    [] -> State(..state, flush_scheduled: False)
    pending_entries -> {
      case state.deps.insert_batch(list.reverse(pending_entries)) {
        Ok(_) ->
          State(
            ..state,
            pending_entries: [],
            pending_count: 0,
            flush_scheduled: False,
          )
        Error(err) -> {
          state.deps.log_error("Failed to insert log entry batch: " <> err)
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
      case state.deps.insert_batch(list.reverse(pending_entries)) {
        Ok(_) -> {
          State(
            ..state,
            pending_entries: [],
            pending_count: 0,
            flush_scheduled: False,
          )
        }
        Error(err) -> {
          state.deps.log_error(
            "Failed to insert log entry batch during shutdown: " <> err,
          )
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
