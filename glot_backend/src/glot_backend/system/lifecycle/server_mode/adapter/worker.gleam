import gleam/erlang/process
import glot_backend/system/lifecycle/server_mode/ports/controller.{
  type Controller,
}
import glot_backend/system/lifecycle/server_mode/worker

pub fn new(subject: process.Subject(worker.Message)) -> Controller {
  controller.Controller(
    current: fn() { worker.get_mode(subject) },
    enter_maintenance: fn() { worker.enter_maintenance(subject) },
    enter_running: fn() { worker.enter_running(subject) },
    enter_shutting_down: fn() { worker.enter_shutting_down(subject) },
  )
}
