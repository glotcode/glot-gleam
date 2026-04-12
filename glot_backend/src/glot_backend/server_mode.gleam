import gleam/erlang/process
import gleam/otp/actor
import gleam/otp/supervision

pub type Mode {
  Running
  Maintenance
}

pub type Message {
  SetMode(mode: Mode)
  GetMode(reply: process.Subject(Mode))
}

type State {
  State(mode: Mode)
}

const call_timeout_ms = 100

pub fn start(name: process.Name(Message)) {
  actor.new(State(mode: Running))
  |> actor.named(name)
  |> actor.on_message(handle_message)
  |> actor.start
}

pub fn supervised(name: process.Name(Message)) {
  supervision.worker(fn() { start(name) })
}

pub fn get_mode(subject: process.Subject(Message)) -> Mode {
  process.call(subject, call_timeout_ms, GetMode)
}

pub fn enter_maintenance(subject: process.Subject(Message)) -> Nil {
  process.send(subject, SetMode(Maintenance))
}

fn handle_message(state: State, message: Message) -> actor.Next(State, Message) {
  case message {
    SetMode(mode) -> actor.continue(State(mode: mode))
    GetMode(reply) -> {
      process.send(reply, state.mode)
      actor.continue(state)
    }
  }
}
