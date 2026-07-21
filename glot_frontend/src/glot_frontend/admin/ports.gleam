import glot_frontend/admin/command
import lustre/effect.{type Effect}

pub type Ports(msg) {
  Ports(execute: fn(command.Command(msg)) -> Effect(msg))
}
