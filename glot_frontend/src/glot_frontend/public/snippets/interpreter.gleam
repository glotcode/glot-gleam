import gleam/list
import glot_frontend/public/snippets/command
import glot_frontend/public/snippets/ports
import lustre/effect.{type Effect}

pub fn run(
  command: command.Command(msg),
  using ports: ports.Ports(msg),
) -> Effect(msg) {
  case command {
    command.None -> effect.none()
    command.Batch(commands) ->
      effect.batch(list.map(commands, fn(command) { run(command, ports) }))
    command.LoadSsr(complete) -> ports.load_ssr(complete)
    command.ListPublicSnippets(request, complete) ->
      ports.list_public_snippets(request, complete)
    command.Schedule(milliseconds, msg) -> ports.schedule(milliseconds, msg)
  }
}
