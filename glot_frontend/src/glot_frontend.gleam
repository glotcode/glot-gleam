import gleam/list
import gleam/option
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_core/auth/session_dto
import glot_core/auth/user_model
import glot_core/page/site_chrome
import glot_core/page/top_bar
import glot_core/pageview_dto
import glot_core/route
import glot_frontend/account_page
import glot_frontend/admin_breadcrumbs
import glot_frontend/admin_api_log_page
import glot_frontend/admin_api_logs_page
import glot_frontend/admin_config_page
import glot_frontend/admin_job_log_page
import glot_frontend/admin_job_logs_page
import glot_frontend/admin_job_page
import glot_frontend/admin_jobs_page
import glot_frontend/admin_page
import glot_frontend/admin_periodic_job_page
import glot_frontend/admin_periodic_jobs_page
import glot_frontend/admin_rate_limits_page
import glot_frontend/admin_run_log_page
import glot_frontend/admin_run_logs_page
import glot_frontend/admin_snippet_page
import glot_frontend/admin_snippets_page
import glot_frontend/admin_user_page
import glot_frontend/admin_users_page
import glot_frontend/api
import glot_frontend/app_dialog
import glot_frontend/app_event
import glot_frontend/clock
import glot_frontend/editor_page
import glot_frontend/home_page
import glot_frontend/keyboard_shortcuts
import glot_frontend/login_page
import glot_frontend/manage_snippets_page
import glot_frontend/quick_action_scroll
import glot_frontend/snippets_page
import glot_frontend/string_helpers
import lustre
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import modem
import youid/uuid

pub fn main() -> Nil {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Flags)

  Nil
}

type Model {
  Model(
    route: route.Route,
    page_model: PageModel,
    session: SessionState,
    now: Timestamp,
    quick_action_query: String,
    quick_action_selected_index: Int,
  )
}

type PageModel {
  HomePageModel(home_page.Model)
  LoginPage(login_page.Model)
  AccountPage(account_page.Model)
  AdminPage(admin_page.Model)
  AdminApiLogsPage(admin_api_logs_page.Model)
  AdminApiLogPage(admin_api_log_page.Model)
  AdminRunLogsPage(admin_run_logs_page.Model)
  AdminRunLogPage(admin_run_log_page.Model)
  AdminPeriodicJobsPage(admin_periodic_jobs_page.Model)
  AdminPeriodicJobPage(admin_periodic_job_page.Model)
  AdminUsersPage(admin_users_page.Model)
  AdminUserPage(admin_user_page.Model)
  AdminJobsPage(admin_jobs_page.Model)
  AdminJobPage(admin_job_page.Model)
  AdminSnippetsPage(admin_snippets_page.Model)
  AdminSnippetPage(admin_snippet_page.Model)
  AdminJobLogsPage(admin_job_logs_page.Model)
  AdminJobLogPage(admin_job_log_page.Model)
  AdminConfigPage(admin_config_page.Model)
  AdminRateLimitsPage(admin_rate_limits_page.Model)
  ManageSnippetsPage(manage_snippets_page.Model)
  SnippetsPage(snippets_page.Model)
  EditorPage(editor_page.Model)
  EmptyPageModel
}

type SessionState {
  LoadingSession
  AnonymousSession
  AuthenticatedSession(session_dto.SessionResponse)
  SessionError
}

type QuickActionTarget {
  NavigateTo(route.Route)
  TriggerEditorAction(editor_page.Msg)
}

fn init_page(
  route: route.Route,
  session: SessionState,
) -> #(PageModel, Effect(Msg)) {
  case route {
    route.Home -> {
      let #(m, eff) = home_page.init()
      #(HomePageModel(m), effect.map(eff, HomePageMsg))
    }

    route.Login -> {
      let #(m, eff) = login_page.init()
      #(LoginPage(m), effect.map(eff, LoginPageMsg))
    }

    route.Account -> {
      let #(m, eff) = account_page.init()
      #(AccountPage(m), effect.map(eff, AccountPageMsg))
    }

    route.Admin -> {
      let #(m, eff) = admin_page.init()
      #(AdminPage(m), effect.map(eff, AdminPageMsg))
    }

    route.AdminApiLogs -> {
      let #(m, eff) = admin_api_logs_page.init()
      let admin_effect = case session_is_admin(session) {
        True ->
          effect.map(
            admin_api_logs_page.ensure_loaded(m).1,
            AdminApiLogsPageMsg,
          )
        False -> effect.none()
      }

      #(
        AdminApiLogsPage(m),
        effect.batch([effect.map(eff, AdminApiLogsPageMsg), admin_effect]),
      )
    }

    route.AdminApiLog(id) -> {
      let #(m, eff) = admin_api_log_page.init(id)
      let admin_effect = case session_is_admin(session) {
        True ->
          effect.map(admin_api_log_page.ensure_loaded(m).1, AdminApiLogPageMsg)
        False -> effect.none()
      }

      #(
        AdminApiLogPage(m),
        effect.batch([effect.map(eff, AdminApiLogPageMsg), admin_effect]),
      )
    }

    route.AdminRunLogs -> {
      let #(m, eff) = admin_run_logs_page.init()
      let admin_effect = case session_is_admin(session) {
        True ->
          effect.map(
            admin_run_logs_page.ensure_loaded(m).1,
            AdminRunLogsPageMsg,
          )
        False -> effect.none()
      }

      #(
        AdminRunLogsPage(m),
        effect.batch([effect.map(eff, AdminRunLogsPageMsg), admin_effect]),
      )
    }

    route.AdminRunLog(id) -> {
      let #(m, eff) = admin_run_log_page.init(id)
      let admin_effect = case session_is_admin(session) {
        True ->
          effect.map(admin_run_log_page.ensure_loaded(m).1, AdminRunLogPageMsg)
        False -> effect.none()
      }

      #(
        AdminRunLogPage(m),
        effect.batch([effect.map(eff, AdminRunLogPageMsg), admin_effect]),
      )
    }

    route.AdminPeriodicJobs -> {
      let #(m, eff) = admin_periodic_jobs_page.init()
      let admin_effect = case session_is_admin(session) {
        True ->
          effect.map(
            admin_periodic_jobs_page.ensure_loaded(m).1,
            AdminPeriodicJobsPageMsg,
          )
        False -> effect.none()
      }

      #(
        AdminPeriodicJobsPage(m),
        effect.batch([effect.map(eff, AdminPeriodicJobsPageMsg), admin_effect]),
      )
    }

    route.AdminPeriodicJob(id) -> {
      let #(m, eff) = admin_periodic_job_page.init(id)
      let admin_effect = case session_is_admin(session) {
        True ->
          effect.map(
            admin_periodic_job_page.ensure_loaded(m).1,
            AdminPeriodicJobPageMsg,
          )
        False -> effect.none()
      }

      #(
        AdminPeriodicJobPage(m),
        effect.batch([effect.map(eff, AdminPeriodicJobPageMsg), admin_effect]),
      )
    }

    route.AdminUsers -> {
      let #(m, eff) = admin_users_page.init()
      let admin_effect = case session_is_admin(session) {
        True -> effect.map(admin_users_page.ensure_loaded(m).1, AdminUsersPageMsg)
        False -> effect.none()
      }

      #(
        AdminUsersPage(m),
        effect.batch([effect.map(eff, AdminUsersPageMsg), admin_effect]),
      )
    }

    route.AdminUser(id) -> {
      let #(m, eff) = admin_user_page.init(id)
      let admin_effect = case session_is_admin(session) {
        True -> effect.map(admin_user_page.ensure_loaded(m).1, AdminUserPageMsg)
        False -> effect.none()
      }

      #(
        AdminUserPage(m),
        effect.batch([effect.map(eff, AdminUserPageMsg), admin_effect]),
      )
    }

    route.AdminJobs -> {
      let #(m, eff) = admin_jobs_page.init()
      let admin_effect = case session_is_admin(session) {
        True -> effect.map(admin_jobs_page.ensure_loaded(m).1, AdminJobsPageMsg)
        False -> effect.none()
      }

      #(
        AdminJobsPage(m),
        effect.batch([effect.map(eff, AdminJobsPageMsg), admin_effect]),
      )
    }

    route.AdminJob(job_id) -> {
      let #(m, eff) = admin_job_page.init(job_id)
      let admin_effect = case session_is_admin(session) {
        True -> effect.map(admin_job_page.ensure_loaded(m).1, AdminJobPageMsg)
        False -> effect.none()
      }

      #(
        AdminJobPage(m),
        effect.batch([effect.map(eff, AdminJobPageMsg), admin_effect]),
      )
    }

    route.AdminSnippets -> {
      let #(m, eff) = admin_snippets_page.init()
      let admin_effect = case session_is_admin(session) {
        True ->
          effect.map(admin_snippets_page.ensure_loaded(m).1, AdminSnippetsPageMsg)
        False -> effect.none()
      }

      #(
        AdminSnippetsPage(m),
        effect.batch([effect.map(eff, AdminSnippetsPageMsg), admin_effect]),
      )
    }

    route.AdminSnippet(slug) -> {
      let #(m, eff) = admin_snippet_page.init(slug)
      let admin_effect = case session_is_admin(session) {
        True ->
          effect.map(admin_snippet_page.ensure_loaded(m).1, AdminSnippetPageMsg)
        False -> effect.none()
      }

      #(
        AdminSnippetPage(m),
        effect.batch([effect.map(eff, AdminSnippetPageMsg), admin_effect]),
      )
    }

    route.AdminJobLogs -> {
      let #(m, eff) = admin_job_logs_page.init()
      let admin_effect = case session_is_admin(session) {
        True ->
          effect.map(
            admin_job_logs_page.ensure_loaded(m).1,
            AdminJobLogsPageMsg,
          )
        False -> effect.none()
      }

      #(
        AdminJobLogsPage(m),
        effect.batch([effect.map(eff, AdminJobLogsPageMsg), admin_effect]),
      )
    }

    route.AdminJobLog(id) -> {
      let #(m, eff) = admin_job_log_page.init(id)
      let admin_effect = case session_is_admin(session) {
        True ->
          effect.map(admin_job_log_page.ensure_loaded(m).1, AdminJobLogPageMsg)
        False -> effect.none()
      }

      #(
        AdminJobLogPage(m),
        effect.batch([effect.map(eff, AdminJobLogPageMsg), admin_effect]),
      )
    }

    route.AdminConfig -> {
      let #(m, eff) = admin_config_page.init()
      let admin_effect = case session_is_admin(session) {
        True ->
          effect.map(admin_config_page.ensure_loaded(m).1, AdminConfigPageMsg)
        False -> effect.none()
      }

      #(
        AdminConfigPage(m),
        effect.batch([effect.map(eff, AdminConfigPageMsg), admin_effect]),
      )
    }

    route.AdminRateLimits -> {
      let #(m, eff) = admin_rate_limits_page.init()
      let admin_effect = case session_is_admin(session) {
        True ->
          effect.map(
            admin_rate_limits_page.ensure_loaded(m).1,
            AdminRateLimitsPageMsg,
          )
        False -> effect.none()
      }

      #(
        AdminRateLimitsPage(m),
        effect.batch([effect.map(eff, AdminRateLimitsPageMsg), admin_effect]),
      )
    }

    route.AccountSnippets(after:, before:) -> {
      let #(m, eff) = manage_snippets_page.init(after:, before:)
      #(ManageSnippetsPage(m), effect.map(eff, ManageSnippetsPageMsg))
    }

    route.Snippets(after:, before:, username:) -> {
      let #(m, eff) = snippets_page.init(after:, before:, username:)
      #(SnippetsPage(m), effect.map(eff, SnippetsPageMsg))
    }

    route.NewSnippet(language) -> {
      let #(m, eff) = editor_page.init_new(language)
      #(EditorPage(m), effect.map(eff, EditorPageMsg))
    }

    route.Snippet(slug) -> {
      let #(m, eff) = editor_page.init_existing(slug)
      #(EditorPage(m), effect.map(eff, EditorPageMsg))
    }

    route.NotFound(_) -> #(EmptyPageModel, effect.none())
  }
}

type Flags {
  Flags
}

fn init(_flags: Flags) -> #(Model, Effect(Msg)) {
  let r = case modem.initial_uri() {
    Ok(uri) -> route.from_uri(uri)
    Error(_) -> route.Home
  }

  let #(page_model, page_effect) = init_page(r, LoadingSession)

  let eff =
    modem.init(fn(uri) {
      uri
      |> route.from_uri
      |> UserNavigatedTo
    })

  let session_effect = api.get_session(SessionLoaded)
  let shortcut_effect =
    keyboard_shortcuts.bind(QuickActionsOpened, EditorRunShortcutPressed)
  let effects =
    effect.batch([
      eff,
      page_effect,
      track_pageview(r),
      session_effect,
      shortcut_effect,
      clock.schedule_next_tick(ClockTicked),
    ])

  #(
    Model(
      route: r,
      page_model: page_model,
      session: LoadingSession,
      now: clock.now(),
      quick_action_query: "",
      quick_action_selected_index: 0,
    ),
    effects,
  )
}

type Msg {
  UserNavigatedTo(route: route.Route)
  PageviewTracked(api.ApiResponse(Nil))
  SessionLoaded(api.ApiResponse(option.Option(session_dto.SessionResponse)))
  ClockTicked(Timestamp)
  QuickActionsOpened
  QuickActionsDismissed
  QuickActionsClosed
  QuickActionsQueryChanged(String)
  QuickActionsKeyPressed(String)
  QuickActionsSubmitted
  QuickActionSelected(QuickActionTarget)
  EditorRunShortcutPressed
  HomePageMsg(home_page.Msg)
  LoginPageMsg(login_page.Msg)
  AccountPageMsg(account_page.Msg)
  AdminPageMsg(admin_page.Msg)
  AdminApiLogsPageMsg(admin_api_logs_page.Msg)
  AdminApiLogPageMsg(admin_api_log_page.Msg)
  AdminRunLogsPageMsg(admin_run_logs_page.Msg)
  AdminRunLogPageMsg(admin_run_log_page.Msg)
  AdminPeriodicJobsPageMsg(admin_periodic_jobs_page.Msg)
  AdminPeriodicJobPageMsg(admin_periodic_job_page.Msg)
  AdminUsersPageMsg(admin_users_page.Msg)
  AdminUserPageMsg(admin_user_page.Msg)
  AdminJobsPageMsg(admin_jobs_page.Msg)
  AdminJobPageMsg(admin_job_page.Msg)
  AdminSnippetsPageMsg(admin_snippets_page.Msg)
  AdminSnippetPageMsg(admin_snippet_page.Msg)
  AdminJobLogsPageMsg(admin_job_logs_page.Msg)
  AdminJobLogPageMsg(admin_job_log_page.Msg)
  AdminConfigPageMsg(admin_config_page.Msg)
  AdminRateLimitsPageMsg(admin_rate_limits_page.Msg)
  ManageSnippetsPageMsg(manage_snippets_page.Msg)
  SnippetsPageMsg(snippets_page.Msg)
  EditorPageMsg(editor_page.Msg)
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg, model.page_model {
    ClockTicked(now), _ -> #(
      Model(..model, now: now),
      clock.schedule_next_tick(ClockTicked),
    )

    SessionLoaded(result), _ -> {
      let session = case result {
        api.ApiSuccess(option.Some(session)) -> AuthenticatedSession(session)
        api.ApiSuccess(option.None) -> AnonymousSession
        api.ApiFailure(_) | api.HttpFailure(_) -> SessionError
      }

      let next_model = Model(..model, session: session)

      case model.route {
        route.Admin
        | route.AdminApiLogs
        | route.AdminApiLog(_)
        | route.AdminRunLogs
        | route.AdminRunLog(_)
        | route.AdminPeriodicJobs
        | route.AdminPeriodicJob(_)
        | route.AdminUsers
        | route.AdminUser(_)
        | route.AdminJobs
        | route.AdminJob(_)
        | route.AdminSnippets
        | route.AdminSnippet(_)
        | route.AdminJobLogs
        | route.AdminJobLog(_)
        | route.AdminConfig
        | route.AdminRateLimits ->
          case session_is_admin(session), model.route, model.page_model {
            True, route.AdminApiLogs, AdminApiLogsPage(page_model) -> {
              let #(new_page_model, page_effect) =
                admin_api_logs_page.ensure_loaded(page_model)
              #(
                Model(
                  ..next_model,
                  page_model: AdminApiLogsPage(new_page_model),
                ),
                effect.map(page_effect, AdminApiLogsPageMsg),
              )
            }
            True, route.AdminApiLog(_), AdminApiLogPage(page_model) -> {
              let #(new_page_model, page_effect) =
                admin_api_log_page.ensure_loaded(page_model)
              #(
                Model(..next_model, page_model: AdminApiLogPage(new_page_model)),
                effect.map(page_effect, AdminApiLogPageMsg),
              )
            }
            True, route.AdminRunLogs, AdminRunLogsPage(page_model) -> {
              let #(new_page_model, page_effect) =
                admin_run_logs_page.ensure_loaded(page_model)
              #(
                Model(..next_model, page_model: AdminRunLogsPage(new_page_model)),
                effect.map(page_effect, AdminRunLogsPageMsg),
              )
            }
            True, route.AdminRunLog(_), AdminRunLogPage(page_model) -> {
              let #(new_page_model, page_effect) =
                admin_run_log_page.ensure_loaded(page_model)
              #(
                Model(..next_model, page_model: AdminRunLogPage(new_page_model)),
                effect.map(page_effect, AdminRunLogPageMsg),
              )
            }
            True, route.AdminPeriodicJobs, AdminPeriodicJobsPage(page_model) -> {
              let #(new_page_model, page_effect) =
                admin_periodic_jobs_page.ensure_loaded(page_model)
              #(
                Model(
                  ..next_model,
                  page_model: AdminPeriodicJobsPage(new_page_model),
                ),
                effect.map(page_effect, AdminPeriodicJobsPageMsg),
              )
            }
            True, route.AdminPeriodicJob(_), AdminPeriodicJobPage(page_model) -> {
              let #(new_page_model, page_effect) =
                admin_periodic_job_page.ensure_loaded(page_model)
              #(
                Model(
                  ..next_model,
                  page_model: AdminPeriodicJobPage(new_page_model),
                ),
                effect.map(page_effect, AdminPeriodicJobPageMsg),
              )
            }
            True, route.AdminUsers, AdminUsersPage(page_model) -> {
              let #(new_page_model, page_effect) =
                admin_users_page.ensure_loaded(page_model)
              #(
                Model(..next_model, page_model: AdminUsersPage(new_page_model)),
                effect.map(page_effect, AdminUsersPageMsg),
              )
            }
            True, route.AdminUser(_), AdminUserPage(page_model) -> {
              let #(new_page_model, page_effect) =
                admin_user_page.ensure_loaded(page_model)
              #(
                Model(..next_model, page_model: AdminUserPage(new_page_model)),
                effect.map(page_effect, AdminUserPageMsg),
              )
            }
            True, route.AdminJobs, AdminJobsPage(page_model) -> {
              let #(new_page_model, page_effect) =
                admin_jobs_page.ensure_loaded(page_model)
              #(
                Model(..next_model, page_model: AdminJobsPage(new_page_model)),
                effect.map(page_effect, AdminJobsPageMsg),
              )
            }
            True, route.AdminJob(_), AdminJobPage(page_model) -> {
              let #(new_page_model, page_effect) =
                admin_job_page.ensure_loaded(page_model)
              #(
                Model(..next_model, page_model: AdminJobPage(new_page_model)),
                effect.map(page_effect, AdminJobPageMsg),
              )
            }
            True, route.AdminSnippets, AdminSnippetsPage(page_model) -> {
              let #(new_page_model, page_effect) =
                admin_snippets_page.ensure_loaded(page_model)
              #(
                Model(
                  ..next_model,
                  page_model: AdminSnippetsPage(new_page_model),
                ),
                effect.map(page_effect, AdminSnippetsPageMsg),
              )
            }
            True, route.AdminSnippet(_), AdminSnippetPage(page_model) -> {
              let #(new_page_model, page_effect) =
                admin_snippet_page.ensure_loaded(page_model)
              #(
                Model(
                  ..next_model,
                  page_model: AdminSnippetPage(new_page_model),
                ),
                effect.map(page_effect, AdminSnippetPageMsg),
              )
            }
            True, route.AdminJobLogs, AdminJobLogsPage(page_model) -> {
              let #(new_page_model, page_effect) =
                admin_job_logs_page.ensure_loaded(page_model)
              #(
                Model(
                  ..next_model,
                  page_model: AdminJobLogsPage(new_page_model),
                ),
                effect.map(page_effect, AdminJobLogsPageMsg),
              )
            }
            True, route.AdminJobLog(_), AdminJobLogPage(page_model) -> {
              let #(new_page_model, page_effect) =
                admin_job_log_page.ensure_loaded(page_model)
              #(
                Model(..next_model, page_model: AdminJobLogPage(new_page_model)),
                effect.map(page_effect, AdminJobLogPageMsg),
              )
            }
            True, route.AdminConfig, AdminConfigPage(page_model) -> {
              let #(new_page_model, page_effect) =
                admin_config_page.ensure_loaded(page_model)
              #(
                Model(..next_model, page_model: AdminConfigPage(new_page_model)),
                effect.map(page_effect, AdminConfigPageMsg),
              )
            }
            True, route.AdminRateLimits, AdminRateLimitsPage(page_model) -> {
              let #(new_page_model, page_effect) =
                admin_rate_limits_page.ensure_loaded(page_model)
              #(
                Model(
                  ..next_model,
                  page_model: AdminRateLimitsPage(new_page_model),
                ),
                effect.map(page_effect, AdminRateLimitsPageMsg),
              )
            }
            False, _, _ -> #(
              next_model,
              replace_route(admin_fallback_route(session)),
            )
            _, _, _ -> #(next_model, effect.none())
          }

        _ -> #(next_model, effect.none())
      }
    }

    PageviewTracked(_), _ -> #(model, effect.none())

    QuickActionsOpened, _ -> #(
      Model(..model, quick_action_query: "", quick_action_selected_index: 0),
      app_dialog.open(top_bar.quick_actions_dialog_id),
    )

    QuickActionsDismissed, _ -> #(
      Model(..model, quick_action_query: "", quick_action_selected_index: 0),
      app_dialog.close(top_bar.quick_actions_dialog_id),
    )

    QuickActionsClosed, _ -> #(
      Model(..model, quick_action_query: "", quick_action_selected_index: 0),
      app_dialog.close(top_bar.quick_actions_dialog_id),
    )

    QuickActionsQueryChanged(query), _ -> #(
      Model(..model, quick_action_query: query, quick_action_selected_index: 0),
      effect.none(),
    )

    QuickActionsKeyPressed(key), _ ->
      case key {
        "ArrowDown" -> move_and_scroll_quick_action_selection(model, 1)
        "ArrowUp" -> move_and_scroll_quick_action_selection(model, -1)
        "Enter" ->
          case selected_quick_action(model) {
            option.Some(action) ->
              case action {
                top_bar.Action(msg:, ..) ->
                  update(Model(..model, quick_action_query: ""), msg)
              }
            option.None -> #(model, effect.none())
          }
        _ -> #(model, effect.none())
      }

    QuickActionsSubmitted, _ ->
      case selected_quick_action(model) {
        option.Some(action) ->
          case action {
            top_bar.Action(msg:, ..) ->
              update(Model(..model, quick_action_query: ""), msg)
          }

        option.None -> #(model, effect.none())
      }

    QuickActionSelected(target), _ ->
      handle_quick_action(Model(..model, quick_action_query: ""), target)

    EditorRunShortcutPressed, EditorPage(page_model) -> {
      let #(new_page_model, page_effect) =
        editor_page.update(
          page_model,
          editor_page.RunSubmitted,
          current_user_id(model.session),
        )
      let new_model = Model(..model, page_model: EditorPage(new_page_model))
      #(new_model, effect.map(page_effect, EditorPageMsg))
    }

    HomePageMsg(page_msg), HomePageModel(page_model) -> {
      let #(new_page_model, page_effect) =
        home_page.update(page_model, page_msg)
      let new_model = Model(..model, page_model: HomePageModel(new_page_model))
      #(new_model, effect.map(page_effect, HomePageMsg))
    }

    LoginPageMsg(page_msg), LoginPage(page_model) -> {
      let #(new_page_model, page_effect, event) =
        login_page.update(page_model, page_msg)
      let new_model = Model(..model, page_model: LoginPage(new_page_model))
      let mapped_effect = effect.map(page_effect, LoginPageMsg)
      #(new_model, apply_app_event(mapped_effect, event))
    }

    AccountPageMsg(page_msg), AccountPage(page_model) -> {
      let #(new_page_model, page_effect, event) =
        account_page.update(page_model, page_msg)
      let new_model = Model(..model, page_model: AccountPage(new_page_model))
      let mapped_effect = effect.map(page_effect, AccountPageMsg)
      #(new_model, apply_app_event(mapped_effect, event))
    }

    AdminPageMsg(page_msg), AdminPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_page.update(page_model, page_msg)
      let new_model = Model(..model, page_model: AdminPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminPageMsg))
    }

    AdminApiLogsPageMsg(page_msg), AdminApiLogsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_api_logs_page.update(page_model, page_msg)
      let new_model =
        Model(..model, page_model: AdminApiLogsPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminApiLogsPageMsg))
    }

    AdminApiLogPageMsg(page_msg), AdminApiLogPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_api_log_page.update(page_model, page_msg)
      let new_model =
        Model(..model, page_model: AdminApiLogPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminApiLogPageMsg))
    }

    AdminRunLogsPageMsg(page_msg), AdminRunLogsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_run_logs_page.update(page_model, page_msg)
      let new_model =
        Model(..model, page_model: AdminRunLogsPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminRunLogsPageMsg))
    }

    AdminRunLogPageMsg(page_msg), AdminRunLogPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_run_log_page.update(page_model, page_msg)
      let new_model =
        Model(..model, page_model: AdminRunLogPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminRunLogPageMsg))
    }

    AdminPeriodicJobsPageMsg(page_msg), AdminPeriodicJobsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_periodic_jobs_page.update(page_model, page_msg)
      let new_model =
        Model(..model, page_model: AdminPeriodicJobsPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminPeriodicJobsPageMsg))
    }

    AdminPeriodicJobPageMsg(page_msg), AdminPeriodicJobPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_periodic_job_page.update(page_model, page_msg)
      let new_model =
        Model(..model, page_model: AdminPeriodicJobPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminPeriodicJobPageMsg))
    }

    AdminUsersPageMsg(page_msg), AdminUsersPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_users_page.update(page_model, page_msg)
      let new_model = Model(..model, page_model: AdminUsersPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminUsersPageMsg))
    }

    AdminUserPageMsg(page_msg), AdminUserPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_user_page.update(page_model, page_msg)
      let new_model = Model(..model, page_model: AdminUserPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminUserPageMsg))
    }

    AdminJobsPageMsg(page_msg), AdminJobsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_jobs_page.update(page_model, page_msg)
      let new_model = Model(..model, page_model: AdminJobsPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminJobsPageMsg))
    }

    AdminJobPageMsg(page_msg), AdminJobPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_job_page.update(page_model, page_msg)
      let new_model = Model(..model, page_model: AdminJobPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminJobPageMsg))
    }

    AdminSnippetsPageMsg(page_msg), AdminSnippetsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_snippets_page.update(page_model, page_msg)
      let new_model =
        Model(..model, page_model: AdminSnippetsPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminSnippetsPageMsg))
    }

    AdminSnippetPageMsg(page_msg), AdminSnippetPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_snippet_page.update(page_model, page_msg)
      let new_model =
        Model(..model, page_model: AdminSnippetPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminSnippetPageMsg))
    }

    AdminJobLogsPageMsg(page_msg), AdminJobLogsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_job_logs_page.update(page_model, page_msg)
      let new_model =
        Model(..model, page_model: AdminJobLogsPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminJobLogsPageMsg))
    }

    AdminJobLogPageMsg(page_msg), AdminJobLogPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_job_log_page.update(page_model, page_msg)
      let new_model =
        Model(..model, page_model: AdminJobLogPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminJobLogPageMsg))
    }

    AdminConfigPageMsg(page_msg), AdminConfigPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_config_page.update(page_model, page_msg)
      let new_model =
        Model(..model, page_model: AdminConfigPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminConfigPageMsg))
    }

    AdminRateLimitsPageMsg(page_msg), AdminRateLimitsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_rate_limits_page.update(page_model, page_msg)
      let new_model =
        Model(..model, page_model: AdminRateLimitsPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminRateLimitsPageMsg))
    }

    ManageSnippetsPageMsg(page_msg), ManageSnippetsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        manage_snippets_page.update(page_model, page_msg)
      let new_model =
        Model(..model, page_model: ManageSnippetsPage(new_page_model))
      #(new_model, effect.map(page_effect, ManageSnippetsPageMsg))
    }

    SnippetsPageMsg(page_msg), SnippetsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        snippets_page.update(page_model, page_msg)
      let new_model = Model(..model, page_model: SnippetsPage(new_page_model))
      #(new_model, effect.map(page_effect, SnippetsPageMsg))
    }

    EditorPageMsg(page_msg), EditorPage(page_model) -> {
      let #(new_page_model, page_effect) =
        editor_page.update(page_model, page_msg, current_user_id(model.session))
      let new_model = Model(..model, page_model: EditorPage(new_page_model))
      #(new_model, effect.map(page_effect, EditorPageMsg))
    }

    UserNavigatedTo(route:), _ -> {
      let destination = authorized_route(route, model.session)
      let #(page_model, page_effect) = init_page(destination, model.session)
      #(
        Model(
          ..model,
          route: destination,
          page_model:,
          quick_action_query: "",
          quick_action_selected_index: 0,
        ),
        effect.batch([
          app_dialog.close(top_bar.quick_actions_dialog_id),
          page_effect,
          track_pageview(destination),
        ]),
      )
    }

    _, _ -> #(model, effect.none())
  }
}

fn view(model: Model) -> Element(Msg) {
  let page_content = case model.page_model {
    EmptyPageModel -> {
      not_found_view()
    }

    HomePageModel(page_model) -> {
      let elem = home_page.view(page_model)
      element.map(elem, HomePageMsg)
    }

    LoginPage(page_model) -> {
      let elem = login_page.view(page_model)
      element.map(elem, LoginPageMsg)
    }

    AccountPage(page_model) -> {
      let elem = account_page.view(page_model, model.now)
      element.map(elem, AccountPageMsg)
    }

    AdminPage(page_model) -> {
      case session_is_admin(model.session) {
        True -> admin_page.view(page_model) |> element.map(AdminPageMsg)
        False -> not_found_view()
      }
    }

    AdminApiLogsPage(page_model) -> {
      case session_is_admin(model.session) {
        True ->
          admin_api_logs_page.view(page_model, model.now)
          |> element.map(AdminApiLogsPageMsg)
        False -> not_found_view()
      }
    }

    AdminApiLogPage(page_model) -> {
      case session_is_admin(model.session) {
        True ->
          admin_api_log_page.view(page_model)
          |> element.map(AdminApiLogPageMsg)
        False -> not_found_view()
      }
    }

    AdminRunLogsPage(page_model) -> {
      case session_is_admin(model.session) {
        True ->
          admin_run_logs_page.view(page_model, model.now)
          |> element.map(AdminRunLogsPageMsg)
        False -> not_found_view()
      }
    }

    AdminRunLogPage(page_model) -> {
      case session_is_admin(model.session) {
        True ->
          admin_run_log_page.view(page_model)
          |> element.map(AdminRunLogPageMsg)
        False -> not_found_view()
      }
    }

    AdminPeriodicJobsPage(page_model) -> {
      case session_is_admin(model.session) {
        True ->
          admin_periodic_jobs_page.view(page_model, model.now)
          |> element.map(AdminPeriodicJobsPageMsg)
        False -> not_found_view()
      }
    }

    AdminPeriodicJobPage(page_model) -> {
      case session_is_admin(model.session) {
        True ->
          admin_periodic_job_page.view(page_model, model.now)
          |> element.map(AdminPeriodicJobPageMsg)
        False -> not_found_view()
      }
    }

    AdminUsersPage(page_model) -> {
      case session_is_admin(model.session) {
        True ->
          admin_users_page.view(page_model, model.now)
          |> element.map(AdminUsersPageMsg)
        False -> not_found_view()
      }
    }

    AdminUserPage(page_model) -> {
      case session_is_admin(model.session) {
        True -> admin_user_page.view(page_model, model.now)
          |> element.map(AdminUserPageMsg)
        False -> not_found_view()
      }
    }

    AdminJobsPage(page_model) -> {
      case session_is_admin(model.session) {
        True ->
          admin_jobs_page.view(page_model, model.now)
          |> element.map(AdminJobsPageMsg)
        False -> not_found_view()
      }
    }

    AdminJobPage(page_model) -> {
      case session_is_admin(model.session) {
        True ->
          admin_job_page.view(page_model, model.now)
          |> element.map(AdminJobPageMsg)
        False -> not_found_view()
      }
    }

    AdminSnippetsPage(page_model) -> {
      case session_is_admin(model.session) {
        True ->
          admin_snippets_page.view(page_model, model.now)
          |> element.map(AdminSnippetsPageMsg)
        False -> not_found_view()
      }
    }

    AdminSnippetPage(page_model) -> {
      case session_is_admin(model.session) {
        True ->
          admin_snippet_page.view(page_model)
          |> element.map(AdminSnippetPageMsg)
        False -> not_found_view()
      }
    }

    AdminJobLogsPage(page_model) -> {
      case session_is_admin(model.session) {
        True ->
          admin_job_logs_page.view(page_model, model.now)
          |> element.map(AdminJobLogsPageMsg)
        False -> not_found_view()
      }
    }

    AdminJobLogPage(page_model) -> {
      case session_is_admin(model.session) {
        True ->
          admin_job_log_page.view(page_model)
          |> element.map(AdminJobLogPageMsg)
        False -> not_found_view()
      }
    }

    AdminConfigPage(page_model) -> {
      case session_is_admin(model.session) {
        True ->
          admin_config_page.view(page_model)
          |> element.map(AdminConfigPageMsg)
        False -> not_found_view()
      }
    }

    AdminRateLimitsPage(page_model) -> {
      case session_is_admin(model.session) {
        True ->
          admin_rate_limits_page.view(page_model)
          |> element.map(AdminRateLimitsPageMsg)
        False -> not_found_view()
      }
    }

    ManageSnippetsPage(page_model) -> {
      let elem = manage_snippets_page.view(page_model, model.now)
      element.map(elem, ManageSnippetsPageMsg)
    }

    SnippetsPage(page_model) -> {
      let elem = snippets_page.view(page_model, model.now)
      element.map(elem, SnippetsPageMsg)
    }

    EditorPage(page_model) -> {
      let elem =
        editor_page.view(page_model, current_user_id(model.session), model.now)
      element.map(elem, EditorPageMsg)
    }
  }

  let content =
    case session_is_admin(model.session) && admin_breadcrumbs.is_admin_route(
      model.route,
    ) {
      True -> admin_breadcrumbs.wrap(model.route, page_content)
      False -> page_content
    }

  site_chrome.view(
    top_bar_model: top_bar_model(model),
    footer_account_route: current_user_route(model.session),
    content: content,
  )
}

fn current_user_id(session: SessionState) -> option.Option(uuid.Uuid) {
  case session {
    AuthenticatedSession(session) -> option.Some(session.user.id)
    LoadingSession | AnonymousSession | SessionError -> option.None
  }
}

fn current_user_label(session: SessionState) -> String {
  case session {
    AuthenticatedSession(session) ->
      case string.length(session.user.username) > 20 {
        True -> string_helpers.truncate_stem_middle(session.user.username, 20)
        False -> session.user.username
      }

    LoadingSession | AnonymousSession | SessionError -> "Account"
  }
}

fn current_user_route(session: SessionState) -> route.Route {
  case session {
    AuthenticatedSession(_) | LoadingSession -> route.Account
    AnonymousSession | SessionError -> route.Login
  }
}

fn top_bar_model(model: Model) -> top_bar.ViewModel(Msg) {
  let sections = filtered_quick_action_sections(model)

  top_bar.ViewModel(
    current_user_label: current_user_label(model.session),
    account_route: current_user_route(model.session),
    search_query: model.quick_action_query,
    selected_index: normalized_selected_index(model),
    open_msg: QuickActionsOpened,
    close_msg: QuickActionsDismissed,
    search_changed: QuickActionsQueryChanged,
    keydown: QuickActionsKeyPressed,
    submit_msg: QuickActionsSubmitted,
    sections: sections,
  )
}

fn navigation_actions(
  session: SessionState,
  current_route: route.Route,
  query: String,
) -> List(top_bar.Action(Msg)) {
  let navigation_state = case session {
    AuthenticatedSession(_) ->
      case session_is_admin(session) {
        True -> top_bar.CanManageAdmin
        False -> top_bar.CanManageAccount
      }
    LoadingSession -> top_bar.CanManageAccount
    AnonymousSession | SessionError -> top_bar.NeedsLogin
  }

  top_bar.navigation_actions(
    navigation_state:,
    current_route:,
    query:,
    on_navigate: fn(destination) {
      QuickActionSelected(NavigateTo(destination))
    },
  )
}

fn page_actions(
  page_model: PageModel,
  current_user_id: option.Option(uuid.Uuid),
) -> List(top_bar.Action(Msg)) {
  case page_model {
    EditorPage(model) ->
      list.map(editor_page.quick_actions(model, current_user_id), fn(action) {
        top_bar.map_action(action, fn(msg) {
          QuickActionSelected(TriggerEditorAction(msg))
        })
      })

    HomePageModel(_)
    | LoginPage(_)
    | AccountPage(_)
    | AdminPage(_)
    | AdminApiLogsPage(_)
    | AdminApiLogPage(_)
    | AdminRunLogsPage(_)
    | AdminRunLogPage(_)
    | AdminPeriodicJobsPage(_)
    | AdminPeriodicJobPage(_)
    | AdminUsersPage(_)
    | AdminUserPage(_)
    | AdminJobsPage(_)
    | AdminJobPage(_)
    | AdminSnippetsPage(_)
    | AdminSnippetPage(_)
    | AdminJobLogsPage(_)
    | AdminJobLogPage(_)
    | AdminConfigPage(_)
    | AdminRateLimitsPage(_)
    | ManageSnippetsPage(_)
    | SnippetsPage(_)
    | EmptyPageModel -> []
  }
}

fn language_actions(query: String) -> List(top_bar.Action(Msg)) {
  top_bar.language_actions(query:, on_navigate: fn(destination) {
    QuickActionSelected(NavigateTo(destination))
  })
}

fn handle_quick_action(
  model: Model,
  target: QuickActionTarget,
) -> #(Model, Effect(Msg)) {
  let close_effect = app_dialog.close(top_bar.quick_actions_dialog_id)

  case target, model.page_model {
    NavigateTo(route), _ -> #(
      model,
      effect.batch([close_effect, navigate_to(route)]),
    )

    TriggerEditorAction(page_msg), EditorPage(page_model) -> {
      let #(new_page_model, page_effect) =
        editor_page.update(page_model, page_msg, current_user_id(model.session))
      let next_model = Model(..model, page_model: EditorPage(new_page_model))
      #(
        next_model,
        effect.batch([close_effect, effect.map(page_effect, EditorPageMsg)]),
      )
    }

    TriggerEditorAction(_), _ -> #(model, close_effect)
  }
}

fn navigate_to(route: route.Route) -> Effect(Msg) {
  let #(path, query) = route.path_and_query(route)
  modem.push(path, query, option.None)
}

fn track_pageview(route: route.Route) -> Effect(Msg) {
  let #(path, query) = route.path_and_query(route)
  let full_path = case query {
    option.Some(query) -> path <> "?" <> query
    option.None -> path
  }

  api.track_pageview(
    pageview_dto.PageviewRequest(
      id: uuid.v7(),
      route: route.name(route),
      path: full_path,
    ),
    PageviewTracked,
  )
}

fn filtered_quick_action_sections(model: Model) -> List(top_bar.Section(Msg)) {
  let query = model.quick_action_query |> string.trim |> string.lowercase
  let uses_default_quick_action_sections = case
    model.session,
    model.route,
    model.page_model,
    query
  {
    LoadingSession, route.Home, HomePageModel(_), "" -> True
    _, _, _, _ -> False
  }

  case uses_default_quick_action_sections {
    True ->
      top_bar.default_quick_action_sections(fn(destination) {
        QuickActionSelected(NavigateTo(destination))
      })
    False -> filtered_quick_action_sections_for_state(model, query)
  }
}

fn filtered_quick_action_sections_for_state(
  model: Model,
  query: String,
) -> List(top_bar.Section(Msg)) {
  top_bar.filter_and_rank_sections(
    [
      #(
        0,
        top_bar.Section(
          title: "Navigation",
          actions: navigation_actions(model.session, model.route, query),
        ),
      ),
      #(
        1,
        top_bar.Section(
          title: "Page actions",
          actions: page_actions(
            model.page_model,
            current_user_id(model.session),
          ),
        ),
      ),
      #(
        2,
        top_bar.Section(title: "Languages", actions: language_actions(query)),
      ),
    ],
    query,
  )
}

fn selected_quick_action(model: Model) -> option.Option(top_bar.Action(Msg)) {
  filtered_quick_action_sections(model)
  |> top_bar.flattened_actions
  |> top_bar.action_at(normalized_selected_index(model))
}

fn normalized_selected_index(model: Model) -> Int {
  top_bar.normalized_selected_index(
    filtered_quick_action_sections(model),
    model.quick_action_selected_index,
  )
}

fn move_quick_action_selection(model: Model, delta: Int) -> Model {
  let wrapped =
    top_bar.wrapped_selected_index(
      filtered_quick_action_sections(model),
      model.quick_action_selected_index,
      delta,
    )
  Model(..model, quick_action_selected_index: wrapped)
}

fn move_and_scroll_quick_action_selection(
  model: Model,
  delta: Int,
) -> #(Model, Effect(Msg)) {
  let next_model = move_quick_action_selection(model, delta)
  let selected_index = normalized_selected_index(next_model)
  #(next_model, quick_action_scroll.ensure_visible(selected_index))
}

fn apply_app_event(
  page_effect: Effect(Msg),
  event: app_event.AppEvent,
) -> Effect(Msg) {
  case event {
    app_event.NoAppEvent -> page_effect
    app_event.RefreshSession ->
      effect.batch([page_effect, api.get_session(SessionLoaded)])
  }
}

fn session_is_admin(session: SessionState) -> Bool {
  case session {
    AuthenticatedSession(session) -> session.user.role == user_model.AdminUser
    LoadingSession | AnonymousSession | SessionError -> False
  }
}

fn authorized_route(
  target_route: route.Route,
  session: SessionState,
) -> route.Route {
  case target_route {
    route.Admin
    | route.AdminApiLogs
    | route.AdminApiLog(_)
    | route.AdminRunLogs
    | route.AdminRunLog(_)
    | route.AdminPeriodicJobs
    | route.AdminPeriodicJob(_)
    | route.AdminUsers
    | route.AdminUser(_)
    | route.AdminJobs
    | route.AdminJob(_)
    | route.AdminSnippets
    | route.AdminSnippet(_)
    | route.AdminJobLogs
    | route.AdminJobLog(_)
    | route.AdminConfig
    | route.AdminRateLimits ->
      case session_is_admin(session) {
        True -> target_route
        False -> admin_fallback_route(session)
      }
    _ -> target_route
  }
}

fn admin_fallback_route(session: SessionState) -> route.Route {
  case session {
    AnonymousSession | SessionError -> route.Login
    AuthenticatedSession(_) | LoadingSession -> route.Home
  }
}

fn replace_route(target_route: route.Route) -> Effect(Msg) {
  let #(path, query) = route.path_and_query(target_route)
  modem.replace(path, query, option.None)
}

fn not_found_view() -> Element(msg) {
  html.div([], [
    html.h2([], [html.text("404 Not Found")]),
  ])
}
