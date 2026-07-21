import glot_frontend/public/contact/command
import glot_frontend/public/contact/ports
import lustre/effect.{type Effect}

pub fn run(
  command: command.Command(msg),
  using ports: ports.Ports(msg),
) -> Effect(msg) {
  case command {
    command.None -> effect.none()
    command.Submit(request, complete) -> ports.submit(request, complete)
  }
}
