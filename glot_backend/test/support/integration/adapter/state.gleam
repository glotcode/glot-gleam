import gleam/erlang/process
import support/integration/model
import support/integration/store/common
import support/process as test_process
import youid/uuid.{type Uuid}

pub opaque type State {
  State(process.Subject(Message))
}

type Message {
  Get(process.Subject(model.TestState))
  Put(model.TestState, process.Subject(Nil))
  Update(fn(model.TestState) -> model.TestState, process.Subject(Nil))
  PopUuid(process.Subject(Uuid))
  Stop(process.Subject(Nil))
}

pub fn new(initial: model.TestState) -> State {
  let ready = process.new_subject()
  let _ =
    process.spawn_unlinked(fn() {
      let subject = process.new_subject()
      process.send(ready, subject)
      loop(subject, initial)
    })
  let subject = test_process.receive(ready)
  State(subject)
}

pub fn get(state: State) -> model.TestState {
  let State(subject) = state
  test_process.call(subject, Get)
}

pub fn put(state: State, value: model.TestState) -> Nil {
  let State(subject) = state
  test_process.call(subject, fn(reply) { Put(value, reply) })
}

pub fn update(
  state: State,
  transform: fn(model.TestState) -> model.TestState,
) -> Nil {
  let State(subject) = state
  test_process.call(subject, fn(reply) { Update(transform, reply) })
}

pub fn pop_uuid(state: State) -> Uuid {
  let State(subject) = state
  test_process.call(subject, PopUuid)
}

pub fn stop(state: State) -> Nil {
  let State(subject) = state
  test_process.call(subject, Stop)
}

fn loop(subject: process.Subject(Message), value: model.TestState) -> Nil {
  case process.receive_forever(subject) {
    Get(reply) -> {
      process.send(reply, value)
      loop(subject, value)
    }
    Put(next, reply) -> {
      process.send(reply, Nil)
      loop(subject, next)
    }
    Update(transform, reply) -> {
      let next = transform(value)
      process.send(reply, Nil)
      loop(subject, next)
    }
    PopUuid(reply) -> {
      let #(id, next) = common.pop_uuid(value)
      process.send(reply, id)
      loop(subject, next)
    }
    Stop(reply) -> process.send(reply, Nil)
  }
}
