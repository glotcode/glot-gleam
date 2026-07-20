import glot_backend/system/lifecycle/server_mode/model.{type Mode}

pub type Controller {
  Controller(
    current: fn() -> Mode,
    enter_maintenance: fn() -> Nil,
    enter_running: fn() -> Nil,
    enter_shutting_down: fn() -> Nil,
  )
}
