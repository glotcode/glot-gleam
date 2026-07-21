import gleam/list
import glot_frontend/public/editor/command
import glot_frontend/public/editor/ports
import lustre/effect.{type Effect}

pub fn run(
  command: command.Command(msg),
  using ports: ports.Ports(msg),
) -> Effect(msg) {
  case command {
    command.None -> effect.none()
    command.Batch(commands) ->
      effect.batch(list.map(commands, fn(command) { run(command, ports) }))
    command.LoadEnvironment(complete) -> ports.load_environment(complete)
    command.LoadNewDraft(language_slug, complete) ->
      ports.load_new_draft(language_slug, complete)
    command.GetSnippet(request, complete) ->
      ports.get_snippet(request, complete)
    command.RunCode(request, complete) -> ports.run_code(request, complete)
    command.GetLanguageVersion(request, complete) ->
      ports.get_language_version(request, complete)
    command.CreateSnippet(request, complete) ->
      ports.create_snippet(request, complete)
    command.UpdateSnippet(request, complete) ->
      ports.update_snippet(request, complete)
    command.LoadExistingDraft(slug, complete) ->
      ports.load_existing_draft(slug, complete)
    command.SaveDraft(model) -> ports.save_draft(model)
    command.ClearDraft(model) -> ports.clear_draft(model)
    command.ClearExistingDraft(slug) -> ports.clear_existing_draft(slug)
    command.SaveSettings(value) -> ports.save_settings(value)
    command.OpenDialog(id) -> ports.open_dialog(id)
    command.OpenDialogNextFrame(id) -> ports.open_dialog_next_frame(id)
    command.CloseDialog(id) -> ports.close_dialog(id)
    command.Focus(id) -> ports.focus(id)
    command.Navigate(path) -> ports.navigate(path)
    command.Schedule(milliseconds, msg) -> ports.schedule(milliseconds, msg)
  }
}
