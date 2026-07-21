import gleam/list
import glot_frontend/account/snippets/command
import glot_frontend/account/snippets/ports
import lustre/effect.{type Effect}

pub fn run(
  command: command.Command(msg),
  using ports: ports.Ports(msg),
) -> Effect(msg) {
  case command {
    command.None -> effect.none()
    command.Batch(commands) ->
      effect.batch(list.map(commands, fn(command) { run(command, ports) }))
    command.ListSnippets(request, complete) ->
      ports.list_snippets(request, complete)
    command.DeleteSnippet(request, complete) ->
      ports.delete_snippet(request, complete)
    command.OpenDialog(id) -> ports.open_dialog(id)
    command.CloseDialog(id) -> ports.close_dialog(id)
    command.Navigate(path, query) -> ports.navigate(path, query)
    command.Schedule(milliseconds, msg) -> ports.schedule(milliseconds, msg)
  }
}
