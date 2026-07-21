import glot_core/loadable
import glot_frontend/admin/command

pub fn ensure_loaded(
  state: loadable.Loadable(data),
  load_command: command.Command(msg),
) -> #(loadable.Loadable(data), command.Command(msg)) {
  case state {
    loadable.NotLoaded -> #(loadable.Loading, load_command)
    loadable.Loading | loadable.Loaded(_) | loadable.LoadError(_) -> #(
      state,
      command.none(),
    )
  }
}
