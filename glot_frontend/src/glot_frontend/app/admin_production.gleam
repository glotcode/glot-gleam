import gleam/list
import gleam/option
import glot_core/route
import glot_frontend/admin/command as admin_command
import glot_frontend/admin/interpreter as admin_interpreter
import glot_frontend/admin/production_ports as admin_ports
import glot_frontend/admin/router as admin_pages
import glot_frontend/api/account
import glot_frontend/app/admin_managed
import glot_frontend/app/runtime_production
import glot_frontend/platform/browser_navigation
import glot_frontend/platform/clock
import glot_frontend/platform/page_visibility
import lustre/effect.{type Effect}
import modem

pub fn run(
  command: admin_managed.Command(admin_command.Command(admin_pages.Msg)),
) -> Effect(admin_managed.Msg(admin_pages.Msg)) {
  case command {
    admin_managed.None -> effect.none()
    admin_managed.Batch(commands) -> effect.batch(list.map(commands, run))
    admin_managed.RunAdmin(command) ->
      admin_interpreter.run(command, using: admin_ports.new())
      |> effect.map(admin_managed.AdminPagesMsg)
    admin_managed.GetSession -> account.get_session(admin_managed.SessionLoaded)
    admin_managed.RefreshSession ->
      account.refresh_session(admin_managed.SessionRefreshed)
    admin_managed.TrackPageview(target) ->
      runtime_production.track_pageview(target, admin_managed.PageviewTracked)
    admin_managed.ScheduleTick ->
      clock.schedule_next_tick(fn(now) {
        admin_managed.ClockTicked(now, page_visibility.document_is_visible())
      })
    admin_managed.ReplaceRoute(target) -> {
      let #(path, query) = route.path_and_query(target)
      modem.replace(path, query, option.None)
    }
    admin_managed.LoadRoute(target) ->
      browser_navigation.load(route.to_string(target))
  }
}
