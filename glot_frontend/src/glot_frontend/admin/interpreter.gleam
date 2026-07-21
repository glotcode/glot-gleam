import glot_frontend/admin/command
import glot_frontend/admin/ports
import lustre/effect.{type Effect}

pub fn run(
  command: command.Command(msg),
  using ports: ports.Ports(msg),
) -> Effect(msg) {
  ports.execute(command)
}
