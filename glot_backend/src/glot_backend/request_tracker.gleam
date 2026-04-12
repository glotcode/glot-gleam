import gleam/erlang/process
import gleam/int
import gleam/otp/actor
import gleam/otp/supervision

pub type Message {
  RequestStarted
  RequestFinished
  GetCount(reply: process.Subject(Int))
}

type State {
  State(in_flight_count: Int)
}

const call_timeout_ms = 100

pub fn start(name: process.Name(Message)) {
  actor.new(State(in_flight_count: 0))
  |> actor.named(name)
  |> actor.on_message(handle_message)
  |> actor.start
}

pub fn supervised(name: process.Name(Message)) {
  supervision.worker(fn() { start(name) })
}

pub fn request_started(subject: process.Subject(Message)) -> Nil {
  process.send(subject, RequestStarted)
}

pub fn request_finished(subject: process.Subject(Message)) -> Nil {
  process.send(subject, RequestFinished)
}

pub fn get_count(subject: process.Subject(Message)) -> Int {
  process.call(subject, call_timeout_ms, GetCount)
}

fn handle_message(state: State, message: Message) -> actor.Next(State, Message) {
  case message {
    RequestStarted ->
      actor.continue(State(in_flight_count: state.in_flight_count + 1))
    RequestFinished ->
      actor.continue(
        State(in_flight_count: int.max(state.in_flight_count - 1, 0)),
      )
    GetCount(reply) -> {
      process.send(reply, state.in_flight_count)
      actor.continue(state)
    }
  }
}
