import gleam/int
import gleam/option
import gleam/result
import gleam/string
import glot_core/admin/auth_config_dto
import glot_core/admin/cleanup_config_dto
import glot_core/admin/debug_config_dto
import glot_core/admin/docker_run_config_dto
import glot_frontend/api
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub type Model {
  Model(
    status: Status,
    debug: DebugSection,
    auth: AuthSection,
    cleanup: CleanupSection,
    docker_run: DockerRunSection,
    debug_loaded: Bool,
    auth_loaded: Bool,
    cleanup_loaded: Bool,
    docker_run_loaded: Bool,
  )
}

pub type Status {
  NotLoaded
  Loading
  Ready
  LoadError(String)
}

pub type DockerRunSection {
  DockerRunSection(
    saved: DockerRunFields,
    draft: DockerRunFields,
    state: SectionState,
  )
}

pub type DockerRunFields {
  DockerRunFields(base_url: String, access_token: String)
}

pub type DebugSection {
  DebugSection(saved: DebugFields, draft: DebugFields, state: SectionState)
}

pub type DebugFields {
  DebugFields(enabled: Bool)
}

pub type AuthSection {
  AuthSection(saved: AuthFields, draft: AuthFields, state: SectionState)
}

pub type AuthFields {
  AuthFields(
    login_token_max_age: String,
    session_token_max_age: String,
    session_cookie_max_age: String,
  )
}

pub type CleanupSection {
  CleanupSection(
    saved: CleanupFields,
    draft: CleanupFields,
    state: SectionState,
  )
}

pub type CleanupFields {
  CleanupFields(
    api_log_retention_days: String,
    page_log_retention_days: String,
    pageview_log_retention_days: String,
    run_log_retention_days: String,
    job_log_retention_days: String,
    jobs_retention_days: String,
    login_tokens_retention_days: String,
    user_actions_retention_days: String,
  )
}

pub type SectionState {
  Idle
  Saving
  Saved
  SaveError(String)
}

pub type Msg {
  DebugLoaded(api.ApiResponse(debug_config_dto.DebugConfigResponse))
  DebugToggleClicked
  DebugResetClicked
  DebugSaveClicked
  DebugSaveFinished(api.ApiResponse(debug_config_dto.DebugConfigResponse))
  AuthLoaded(api.ApiResponse(auth_config_dto.AuthConfigResponse))
  AuthLoginTokenMaxAgeChanged(String)
  AuthSessionTokenMaxAgeChanged(String)
  AuthSessionCookieMaxAgeChanged(String)
  AuthResetClicked
  AuthSaveClicked
  AuthSaveFinished(api.ApiResponse(auth_config_dto.AuthConfigResponse))
  CleanupLoaded(api.ApiResponse(cleanup_config_dto.CleanupConfigResponse))
  CleanupApiLogRetentionDaysChanged(String)
  CleanupPageLogRetentionDaysChanged(String)
  CleanupPageviewLogRetentionDaysChanged(String)
  CleanupRunLogRetentionDaysChanged(String)
  CleanupJobLogRetentionDaysChanged(String)
  CleanupJobsRetentionDaysChanged(String)
  CleanupLoginTokensRetentionDaysChanged(String)
  CleanupUserActionsRetentionDaysChanged(String)
  CleanupResetClicked
  CleanupSaveClicked
  CleanupSaveFinished(api.ApiResponse(cleanup_config_dto.CleanupConfigResponse))
  DockerRunLoaded(
    api.ApiResponse(docker_run_config_dto.DockerRunConfigResponse),
  )
  DockerRunBaseUrlChanged(String)
  DockerRunAccessTokenChanged(String)
  DockerRunResetClicked
  DockerRunSaveClicked
  DockerRunSaveFinished(
    api.ApiResponse(docker_run_config_dto.DockerRunConfigResponse),
  )
}

pub fn init() -> #(Model, Effect(Msg)) {
  #(
    Model(
      status: NotLoaded,
      debug: empty_debug_section(),
      auth: empty_auth_section(),
      cleanup: empty_cleanup_section(),
      docker_run: empty_docker_run_section(),
      debug_loaded: False,
      auth_loaded: False,
      cleanup_loaded: False,
      docker_run_loaded: False,
    ),
    effect.none(),
  )
}

pub fn ensure_loaded(model: Model) -> #(Model, Effect(Msg)) {
  case model.status {
    NotLoaded -> #(
      Model(..model, status: Loading),
      effect.batch([
        load_debug_config(),
        load_auth_config(),
        load_cleanup_config(),
        load_docker_run_config(),
      ]),
    )
    Loading | Ready | LoadError(_) -> #(model, effect.none())
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    DebugLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> {
          let fields = debug_fields_from_response(response)
          let next_model =
            Model(
              ..model,
              debug: DebugSection(saved: fields, draft: fields, state: Idle),
              debug_loaded: True,
            )

          #(
            Model(..next_model, status: loaded_status(next_model)),
            effect.none(),
          )
        }
        api.ApiFailure(error) -> #(
          Model(..model, status: LoadError(error.message)),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(..model, status: LoadError("Could not load debug config.")),
          effect.none(),
        )
      }

    DebugToggleClicked -> #(
      Model(
        ..model,
        debug: DebugSection(
          ..model.debug,
          draft: DebugFields(enabled: !model.debug.draft.enabled),
          state: Idle,
        ),
      ),
      effect.none(),
    )

    DebugResetClicked -> #(
      Model(
        ..model,
        debug: DebugSection(
          ..model.debug,
          draft: model.debug.saved,
          state: Idle,
        ),
      ),
      effect.none(),
    )

    DebugSaveClicked -> #(
      Model(..model, debug: DebugSection(..model.debug, state: Saving)),
      api.upsert_admin_debug_config(
        debug_config_dto.UpsertDebugConfigRequest(
          enabled: model.debug.draft.enabled,
        ),
        DebugSaveFinished,
      ),
    )

    DebugSaveFinished(result) ->
      case result {
        api.ApiSuccess(response) -> {
          let fields = debug_fields_from_response(response)
          #(
            Model(
              ..model,
              debug: DebugSection(saved: fields, draft: fields, state: Saved),
            ),
            effect.none(),
          )
        }
        api.ApiFailure(error) -> #(
          Model(
            ..model,
            debug: DebugSection(..model.debug, state: SaveError(error.message)),
          ),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(
            ..model,
            debug: DebugSection(
              ..model.debug,
              state: SaveError("Could not save debug config."),
            ),
          ),
          effect.none(),
        )
      }

    AuthLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> {
          let fields = auth_fields_from_response(response)
          let next_model =
            Model(
              ..model,
              auth: AuthSection(saved: fields, draft: fields, state: Idle),
              auth_loaded: True,
            )

          #(
            Model(..next_model, status: loaded_status(next_model)),
            effect.none(),
          )
        }
        api.ApiFailure(error) -> #(
          Model(..model, status: LoadError(error.message)),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(..model, status: LoadError("Could not load auth config.")),
          effect.none(),
        )
      }

    AuthLoginTokenMaxAgeChanged(value) -> #(
      Model(
        ..model,
        auth: AuthSection(
          ..model.auth,
          draft: AuthFields(..model.auth.draft, login_token_max_age: value),
          state: Idle,
        ),
      ),
      effect.none(),
    )

    AuthSessionTokenMaxAgeChanged(value) -> #(
      Model(
        ..model,
        auth: AuthSection(
          ..model.auth,
          draft: AuthFields(..model.auth.draft, session_token_max_age: value),
          state: Idle,
        ),
      ),
      effect.none(),
    )

    AuthSessionCookieMaxAgeChanged(value) -> #(
      Model(
        ..model,
        auth: AuthSection(
          ..model.auth,
          draft: AuthFields(..model.auth.draft, session_cookie_max_age: value),
          state: Idle,
        ),
      ),
      effect.none(),
    )

    AuthResetClicked -> #(
      Model(
        ..model,
        auth: AuthSection(..model.auth, draft: model.auth.saved, state: Idle),
      ),
      effect.none(),
    )

    AuthSaveClicked ->
      case validate_auth_fields(model.auth.draft) {
        Error(message) -> #(
          Model(
            ..model,
            auth: AuthSection(..model.auth, state: SaveError(message)),
          ),
          effect.none(),
        )
        Ok(request) -> #(
          Model(..model, auth: AuthSection(..model.auth, state: Saving)),
          api.upsert_admin_auth_config(request, AuthSaveFinished),
        )
      }

    AuthSaveFinished(result) ->
      case result {
        api.ApiSuccess(response) -> {
          let fields = auth_fields_from_response(response)
          #(
            Model(
              ..model,
              auth: AuthSection(saved: fields, draft: fields, state: Saved),
            ),
            effect.none(),
          )
        }
        api.ApiFailure(error) -> #(
          Model(
            ..model,
            auth: AuthSection(..model.auth, state: SaveError(error.message)),
          ),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(
            ..model,
            auth: AuthSection(
              ..model.auth,
              state: SaveError("Could not save auth config."),
            ),
          ),
          effect.none(),
        )
      }

    CleanupLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> {
          let fields = cleanup_fields_from_response(response)
          let next_model =
            Model(
              ..model,
              cleanup: CleanupSection(saved: fields, draft: fields, state: Idle),
              cleanup_loaded: True,
            )

          #(
            Model(..next_model, status: loaded_status(next_model)),
            effect.none(),
          )
        }
        api.ApiFailure(error) -> #(
          Model(..model, status: LoadError(error.message)),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(..model, status: LoadError("Could not load cleanup config.")),
          effect.none(),
        )
      }

    CleanupApiLogRetentionDaysChanged(value) -> #(
      Model(
        ..model,
        cleanup: CleanupSection(
          ..model.cleanup,
          draft: CleanupFields(
            ..model.cleanup.draft,
            api_log_retention_days: value,
          ),
          state: Idle,
        ),
      ),
      effect.none(),
    )

    CleanupPageLogRetentionDaysChanged(value) -> #(
      Model(
        ..model,
        cleanup: CleanupSection(
          ..model.cleanup,
          draft: CleanupFields(
            ..model.cleanup.draft,
            page_log_retention_days: value,
          ),
          state: Idle,
        ),
      ),
      effect.none(),
    )

    CleanupPageviewLogRetentionDaysChanged(value) -> #(
      Model(
        ..model,
        cleanup: CleanupSection(
          ..model.cleanup,
          draft: CleanupFields(
            ..model.cleanup.draft,
            pageview_log_retention_days: value,
          ),
          state: Idle,
        ),
      ),
      effect.none(),
    )

    CleanupRunLogRetentionDaysChanged(value) -> #(
      Model(
        ..model,
        cleanup: CleanupSection(
          ..model.cleanup,
          draft: CleanupFields(
            ..model.cleanup.draft,
            run_log_retention_days: value,
          ),
          state: Idle,
        ),
      ),
      effect.none(),
    )

    CleanupJobLogRetentionDaysChanged(value) -> #(
      Model(
        ..model,
        cleanup: CleanupSection(
          ..model.cleanup,
          draft: CleanupFields(
            ..model.cleanup.draft,
            job_log_retention_days: value,
          ),
          state: Idle,
        ),
      ),
      effect.none(),
    )

    CleanupJobsRetentionDaysChanged(value) -> #(
      Model(
        ..model,
        cleanup: CleanupSection(
          ..model.cleanup,
          draft: CleanupFields(
            ..model.cleanup.draft,
            jobs_retention_days: value,
          ),
          state: Idle,
        ),
      ),
      effect.none(),
    )

    CleanupLoginTokensRetentionDaysChanged(value) -> #(
      Model(
        ..model,
        cleanup: CleanupSection(
          ..model.cleanup,
          draft: CleanupFields(
            ..model.cleanup.draft,
            login_tokens_retention_days: value,
          ),
          state: Idle,
        ),
      ),
      effect.none(),
    )

    CleanupUserActionsRetentionDaysChanged(value) -> #(
      Model(
        ..model,
        cleanup: CleanupSection(
          ..model.cleanup,
          draft: CleanupFields(
            ..model.cleanup.draft,
            user_actions_retention_days: value,
          ),
          state: Idle,
        ),
      ),
      effect.none(),
    )

    CleanupResetClicked -> #(
      Model(
        ..model,
        cleanup: CleanupSection(
          ..model.cleanup,
          draft: model.cleanup.saved,
          state: Idle,
        ),
      ),
      effect.none(),
    )

    CleanupSaveClicked ->
      case validate_cleanup_fields(model.cleanup.draft) {
        Error(message) -> #(
          Model(
            ..model,
            cleanup: CleanupSection(..model.cleanup, state: SaveError(message)),
          ),
          effect.none(),
        )
        Ok(request) -> #(
          Model(
            ..model,
            cleanup: CleanupSection(..model.cleanup, state: Saving),
          ),
          api.upsert_admin_cleanup_config(request, CleanupSaveFinished),
        )
      }

    CleanupSaveFinished(result) ->
      case result {
        api.ApiSuccess(response) -> {
          let fields = cleanup_fields_from_response(response)
          #(
            Model(
              ..model,
              cleanup: CleanupSection(
                saved: fields,
                draft: fields,
                state: Saved,
              ),
            ),
            effect.none(),
          )
        }
        api.ApiFailure(error) -> #(
          Model(
            ..model,
            cleanup: CleanupSection(
              ..model.cleanup,
              state: SaveError(error.message),
            ),
          ),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(
            ..model,
            cleanup: CleanupSection(
              ..model.cleanup,
              state: SaveError("Could not save cleanup config."),
            ),
          ),
          effect.none(),
        )
      }

    DockerRunLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> {
          let fields = docker_run_fields_from_response(response)
          let next_model =
            Model(
              ..model,
              docker_run: DockerRunSection(
                saved: fields,
                draft: fields,
                state: Idle,
              ),
              docker_run_loaded: True,
            )

          #(
            Model(..next_model, status: loaded_status(next_model)),
            effect.none(),
          )
        }
        api.ApiFailure(error) ->
          case error.code {
            "docker_run_config_not_found" -> {
              let next_model =
                Model(
                  ..model,
                  docker_run: empty_docker_run_section(),
                  docker_run_loaded: True,
                )

              #(
                Model(..next_model, status: loaded_status(next_model)),
                effect.none(),
              )
            }
            _ -> #(
              Model(..model, status: LoadError(error.message)),
              effect.none(),
            )
          }
        api.HttpFailure(_) -> #(
          Model(..model, status: LoadError("Could not load docker run config.")),
          effect.none(),
        )
      }

    DockerRunBaseUrlChanged(value) -> #(
      Model(
        ..model,
        docker_run: DockerRunSection(
          ..model.docker_run,
          draft: DockerRunFields(..model.docker_run.draft, base_url: value),
          state: Idle,
        ),
      ),
      effect.none(),
    )

    DockerRunAccessTokenChanged(value) -> #(
      Model(
        ..model,
        docker_run: DockerRunSection(
          ..model.docker_run,
          draft: DockerRunFields(..model.docker_run.draft, access_token: value),
          state: Idle,
        ),
      ),
      effect.none(),
    )

    DockerRunResetClicked -> #(
      Model(
        ..model,
        docker_run: DockerRunSection(
          ..model.docker_run,
          draft: model.docker_run.saved,
          state: Idle,
        ),
      ),
      effect.none(),
    )

    DockerRunSaveClicked ->
      case validate_docker_run_fields(model.docker_run.draft) {
        Error(message) -> #(
          Model(
            ..model,
            docker_run: DockerRunSection(
              ..model.docker_run,
              state: SaveError(message),
            ),
          ),
          effect.none(),
        )
        Ok(request) -> #(
          Model(
            ..model,
            docker_run: DockerRunSection(..model.docker_run, state: Saving),
          ),
          api.upsert_admin_docker_run_config(request, DockerRunSaveFinished),
        )
      }

    DockerRunSaveFinished(result) ->
      case result {
        api.ApiSuccess(response) -> {
          let fields = docker_run_fields_from_response(response)
          #(
            Model(
              ..model,
              docker_run: DockerRunSection(
                saved: fields,
                draft: fields,
                state: Saved,
              ),
            ),
            effect.none(),
          )
        }
        api.ApiFailure(error) -> #(
          Model(
            ..model,
            docker_run: DockerRunSection(
              ..model.docker_run,
              state: SaveError(error.message),
            ),
          ),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(
            ..model,
            docker_run: DockerRunSection(
              ..model.docker_run,
              state: SaveError("Could not save docker run config."),
            ),
          ),
          effect.none(),
        )
      }
  }
}

pub fn view(model: Model) -> Element(Msg) {
  html.div([attribute.class("app-page")], [
    html.div([attribute.class("app-page__screen-glow")], []),
    html.main([attribute.class("app-shell")], [
      html.section([attribute.class("app-panel admin-page")], [
        html.div([attribute.class("admin-page__header")], [
          html.div([], [
            html.h2([attribute.class("admin-page__title")], [
              html.text("App config"),
            ]),
          ]),
        ]),
        status_banner(model.status),
        html.div([attribute.class("admin-page__group")], [
          html.div([attribute.class("admin-page__section-grid")], [
            debug_section_view(model.debug, model.status),
            auth_section_view(model.auth, model.status),
            cleanup_section_view(model.cleanup, model.status),
            docker_run_section_view(model.docker_run, model.status),
          ]),
        ]),
      ]),
    ]),
  ])
}

fn auth_section_view(section: AuthSection, status: Status) -> Element(Msg) {
  let save_disabled =
    status != Ready || section.state == Saving || !is_dirty_auth(section)

  html.article(
    [attribute.class("admin-page__policy admin-page__policy--config")],
    [
      html.div([attribute.class("admin-page__policy-header")], [
        html.div([], [
          html.h3([attribute.class("admin-page__policy-title")], [
            html.text("Auth"),
          ]),
          html.p([attribute.class("admin-page__policy-subtitle")], [
            html.text(
              "Controls login token and session expiration values used by the backend.",
            ),
          ]),
        ]),
        html.div([attribute.class("admin-page__policy-header-actions")], [
          auth_status_badge(section),
        ]),
      ]),
      html.div([attribute.class("admin-page__field-grid")], [
        text_input(
          label: "Login token max age",
          help: "Seconds before a login token expires.",
          value: section.draft.login_token_max_age,
          on_input: AuthLoginTokenMaxAgeChanged,
        ),
        text_input(
          label: "Session token max age",
          help: "Seconds before a session becomes invalid.",
          value: section.draft.session_token_max_age,
          on_input: AuthSessionTokenMaxAgeChanged,
        ),
        text_input(
          label: "Session cookie max age",
          help: "Seconds used when setting the signed session cookie.",
          value: section.draft.session_cookie_max_age,
          on_input: AuthSessionCookieMaxAgeChanged,
        ),
      ]),
      html.div([attribute.class("admin-page__policy-footer")], [
        auth_section_message(section),
        html.div([attribute.class("admin-page__policy-actions")], [
          html.button(
            [
              attribute.type_("button"),
              attribute.class(
                "admin-page__button admin-page__button--secondary",
              ),
              attribute.disabled(
                section.state == Saving || !is_dirty_auth(section),
              ),
              event.on_click(AuthResetClicked),
            ],
            [html.text("Reset")],
          ),
          html.button(
            [
              attribute.type_("button"),
              attribute.class("admin-page__button"),
              attribute.disabled(save_disabled),
              event.on_click(AuthSaveClicked),
            ],
            [
              html.text(case section.state {
                Saving -> "Saving..."
                _ -> "Save"
              }),
            ],
          ),
        ]),
      ]),
    ],
  )
}

fn cleanup_section_view(
  section: CleanupSection,
  status: Status,
) -> Element(Msg) {
  let save_disabled =
    status != Ready || section.state == Saving || !is_dirty_cleanup(section)

  html.article(
    [attribute.class("admin-page__policy admin-page__policy--config")],
    [
      html.div([attribute.class("admin-page__policy-header")], [
        html.div([], [
          html.h3([attribute.class("admin-page__policy-title")], [
            html.text("Cleanup"),
          ]),
          html.p([attribute.class("admin-page__policy-subtitle")], [
            html.text(
              "Controls retention windows, in days, for scheduled cleanup jobs.",
            ),
          ]),
        ]),
        html.div([attribute.class("admin-page__policy-header-actions")], [
          cleanup_status_badge(section),
        ]),
      ]),
      html.div([attribute.class("admin-page__field-grid")], [
        text_input(
          label: "API log retention",
          help: "Days to keep API log records.",
          value: section.draft.api_log_retention_days,
          on_input: CleanupApiLogRetentionDaysChanged,
        ),
        text_input(
          label: "Page log retention",
          help: "Days to keep page log records.",
          value: section.draft.page_log_retention_days,
          on_input: CleanupPageLogRetentionDaysChanged,
        ),
        text_input(
          label: "Pageview log retention",
          help: "Days to keep pageview log records.",
          value: section.draft.pageview_log_retention_days,
          on_input: CleanupPageviewLogRetentionDaysChanged,
        ),
        text_input(
          label: "Run log retention",
          help: "Days to keep run log records.",
          value: section.draft.run_log_retention_days,
          on_input: CleanupRunLogRetentionDaysChanged,
        ),
        text_input(
          label: "Job log retention",
          help: "Days to keep job log records.",
          value: section.draft.job_log_retention_days,
          on_input: CleanupJobLogRetentionDaysChanged,
        ),
        text_input(
          label: "Jobs retention",
          help: "Days to keep completed jobs.",
          value: section.draft.jobs_retention_days,
          on_input: CleanupJobsRetentionDaysChanged,
        ),
        text_input(
          label: "Login token retention",
          help: "Days to keep used or expired login tokens.",
          value: section.draft.login_tokens_retention_days,
          on_input: CleanupLoginTokensRetentionDaysChanged,
        ),
        text_input(
          label: "User actions retention",
          help: "Days to keep user action audit records.",
          value: section.draft.user_actions_retention_days,
          on_input: CleanupUserActionsRetentionDaysChanged,
        ),
      ]),
      html.div([attribute.class("admin-page__policy-footer")], [
        cleanup_section_message(section),
        html.div([attribute.class("admin-page__policy-actions")], [
          html.button(
            [
              attribute.type_("button"),
              attribute.class(
                "admin-page__button admin-page__button--secondary",
              ),
              attribute.disabled(
                section.state == Saving || !is_dirty_cleanup(section),
              ),
              event.on_click(CleanupResetClicked),
            ],
            [html.text("Reset")],
          ),
          html.button(
            [
              attribute.type_("button"),
              attribute.class("admin-page__button"),
              attribute.disabled(save_disabled),
              event.on_click(CleanupSaveClicked),
            ],
            [
              html.text(case section.state {
                Saving -> "Saving..."
                _ -> "Save"
              }),
            ],
          ),
        ]),
      ]),
    ],
  )
}

fn status_banner(status: Status) -> Element(Msg) {
  case status {
    NotLoaded | Ready -> html.div([], [])
    Loading ->
      html.p([attribute.class("admin-page__status")], [
        html.text("Loading configuration..."),
      ])
    LoadError(message) ->
      html.p([attribute.class("admin-page__status admin-page__status--error")], [
        html.text(message),
      ])
  }
}

fn debug_section_view(section: DebugSection, status: Status) -> Element(Msg) {
  let save_disabled =
    status != Ready || section.state == Saving || !is_dirty_debug(section)

  html.article(
    [attribute.class("admin-page__policy admin-page__policy--config")],
    [
      html.div([attribute.class("admin-page__policy-header")], [
        html.div([], [
          html.h3([attribute.class("admin-page__policy-title")], [
            html.text("Debug"),
          ]),
          html.p([attribute.class("admin-page__policy-subtitle")], [
            html.text(
              "Controls whether backend debug log fields are collected into API and page logs.",
            ),
          ]),
        ]),
        html.div([attribute.class("admin-page__policy-header-actions")], [
          debug_status_badge(section),
        ]),
      ]),
      html.div([attribute.class("admin-page__field-grid")], [
        html.div([attribute.class("admin-page__field")], [
          html.span([attribute.class("admin-page__field-label")], [
            html.text("Debug logging"),
          ]),
          html.button(
            [
              attribute.type_("button"),
              attribute.class(
                "admin-page__button admin-page__button--secondary",
              ),
              attribute.disabled(status != Ready || section.state == Saving),
              event.on_click(DebugToggleClicked),
            ],
            [
              html.text(case section.draft.enabled {
                True -> "Enabled"
                False -> "Disabled"
              }),
            ],
          ),
          html.span([attribute.class("admin-page__field-help")], [
            html.text(
              "When enabled, debug fields are persisted with API logs. Toggle to change the draft value.",
            ),
          ]),
        ]),
      ]),
      html.div([attribute.class("admin-page__policy-footer")], [
        debug_section_message(section),
        html.div([attribute.class("admin-page__policy-actions")], [
          html.button(
            [
              attribute.type_("button"),
              attribute.class(
                "admin-page__button admin-page__button--secondary",
              ),
              attribute.disabled(
                section.state == Saving || !is_dirty_debug(section),
              ),
              event.on_click(DebugResetClicked),
            ],
            [html.text("Reset")],
          ),
          html.button(
            [
              attribute.type_("button"),
              attribute.class("admin-page__button"),
              attribute.disabled(save_disabled),
              event.on_click(DebugSaveClicked),
            ],
            [
              html.text(case section.state {
                Saving -> "Saving..."
                _ -> "Save"
              }),
            ],
          ),
        ]),
      ]),
    ],
  )
}

fn docker_run_section_view(
  section: DockerRunSection,
  status: Status,
) -> Element(Msg) {
  let save_disabled =
    status != Ready || section.state == Saving || !is_dirty(section)

  html.article(
    [attribute.class("admin-page__policy admin-page__policy--config")],
    [
      html.div([attribute.class("admin-page__policy-header")], [
        html.div([], [
          html.h3([attribute.class("admin-page__policy-title")], [
            html.text("Docker run"),
          ]),
          html.p([attribute.class("admin-page__policy-subtitle")], [
            html.text(
              "Controls the base URL and access token used when the backend calls the docker-run service.",
            ),
          ]),
        ]),
        html.div([attribute.class("admin-page__policy-header-actions")], [
          status_badge(section),
        ]),
      ]),
      html.div([attribute.class("admin-page__field-grid")], [
        text_input(
          label: "Base URL",
          help: "Example: https://docker-run.internal",
          value: section.draft.base_url,
          on_input: DockerRunBaseUrlChanged,
        ),
        text_input(
          label: "Access token",
          help: "Stored as a regular app config value.",
          value: section.draft.access_token,
          on_input: DockerRunAccessTokenChanged,
        ),
      ]),
      html.div([attribute.class("admin-page__policy-footer")], [
        section_message(section),
        html.div([attribute.class("admin-page__policy-actions")], [
          html.button(
            [
              attribute.type_("button"),
              attribute.class(
                "admin-page__button admin-page__button--secondary",
              ),
              attribute.disabled(section.state == Saving || !is_dirty(section)),
              event.on_click(DockerRunResetClicked),
            ],
            [html.text("Reset")],
          ),
          html.button(
            [
              attribute.type_("button"),
              attribute.class("admin-page__button"),
              attribute.disabled(save_disabled),
              event.on_click(DockerRunSaveClicked),
            ],
            [
              html.text(case section.state {
                Saving -> "Saving..."
                _ -> "Save"
              }),
            ],
          ),
        ]),
      ]),
    ],
  )
}

fn text_input(
  label label: String,
  help help: String,
  value value: String,
  on_input on_input: fn(String) -> Msg,
) -> Element(Msg) {
  html.label([attribute.class("admin-page__field")], [
    html.span([attribute.class("admin-page__field-label")], [
      html.text(label),
    ]),
    html.input([
      attribute.type_("text"),
      attribute.class("admin-page__input"),
      attribute.value(value),
      event.on_input(on_input),
    ]),
    html.span([attribute.class("admin-page__field-help")], [
      html.text(help),
    ]),
  ])
}

fn status_badge(section: DockerRunSection) -> Element(Msg) {
  case
    section.state,
    section.saved == empty_docker_run_fields(),
    is_dirty(section)
  {
    Idle, False, False -> html.div([], [])
    _, _, _ ->
      html.span([attribute.class(status_badge_class(section))], [
        html.text(status_badge_text(section)),
      ])
  }
}

fn status_badge_text(section: DockerRunSection) -> String {
  case section.state {
    SaveError(_) -> "Error"
    Saving -> "Saving"
    Saved -> "Saved"
    Idle ->
      case section.saved == empty_docker_run_fields(), is_dirty(section) {
        True, False -> "Not configured"
        _, True -> "Unsaved"
        _, False -> ""
      }
  }
}

fn status_badge_class(section: DockerRunSection) -> String {
  case section.state {
    SaveError(_) -> "admin-page__version admin-page__version--error"
    Saving -> "admin-page__version"
    Saved -> "admin-page__version admin-page__version--success"
    Idle ->
      case section.saved == empty_docker_run_fields(), is_dirty(section) {
        True, False -> "admin-page__version"
        _, True -> "admin-page__version admin-page__version--dirty"
        _, False -> "admin-page__version"
      }
  }
}

fn section_message(section: DockerRunSection) -> Element(Msg) {
  let message = case section.state {
    SaveError(message) ->
      option.Some(#(
        "admin-page__policy-status admin-page__policy-status--error",
        message,
      ))
    Saving -> option.Some(#("admin-page__policy-status", "Saving changes..."))
    Saved -> option.Some(#("admin-page__policy-status", "Config saved."))
    Idle ->
      case section.saved == empty_docker_run_fields(), is_dirty(section) {
        True, False ->
          option.Some(#(
            "admin-page__policy-status",
            "This section is empty until you save initial values.",
          ))
        _, True -> option.None
        _, False -> option.None
      }
  }

  case message {
    option.Some(#(class_name, text)) ->
      html.p([attribute.class(class_name)], [html.text(text)])
    option.None -> html.div([], [])
  }
}

fn debug_status_badge(section: DebugSection) -> Element(Msg) {
  case section.state, is_dirty_debug(section) {
    Idle, False -> html.div([], [])
    _, _ ->
      html.span([attribute.class(debug_status_badge_class(section))], [
        html.text(debug_status_badge_text(section)),
      ])
  }
}

fn debug_status_badge_text(section: DebugSection) -> String {
  case section.state {
    SaveError(_) -> "Error"
    Saving -> "Saving"
    Saved -> "Saved"
    Idle ->
      case is_dirty_debug(section) {
        True -> "Unsaved"
        False -> ""
      }
  }
}

fn debug_status_badge_class(section: DebugSection) -> String {
  case section.state {
    SaveError(_) -> "admin-page__version admin-page__version--error"
    Saving -> "admin-page__version"
    Saved -> "admin-page__version admin-page__version--success"
    Idle ->
      case is_dirty_debug(section) {
        True -> "admin-page__version admin-page__version--dirty"
        False -> "admin-page__version"
      }
  }
}

fn debug_section_message(section: DebugSection) -> Element(Msg) {
  section_state_message(section.state)
}

fn auth_status_badge(section: AuthSection) -> Element(Msg) {
  case section.state, is_dirty_auth(section) {
    Idle, False -> html.div([], [])
    _, _ ->
      html.span([attribute.class(auth_status_badge_class(section))], [
        html.text(auth_status_badge_text(section)),
      ])
  }
}

fn auth_status_badge_text(section: AuthSection) -> String {
  case section.state {
    SaveError(_) -> "Error"
    Saving -> "Saving"
    Saved -> "Saved"
    Idle ->
      case is_dirty_auth(section) {
        True -> "Unsaved"
        False -> ""
      }
  }
}

fn auth_status_badge_class(section: AuthSection) -> String {
  case section.state {
    SaveError(_) -> "admin-page__version admin-page__version--error"
    Saving -> "admin-page__version"
    Saved -> "admin-page__version admin-page__version--success"
    Idle ->
      case is_dirty_auth(section) {
        True -> "admin-page__version admin-page__version--dirty"
        False -> "admin-page__version"
      }
  }
}

fn auth_section_message(section: AuthSection) -> Element(Msg) {
  section_state_message(section.state)
}

fn cleanup_status_badge(section: CleanupSection) -> Element(Msg) {
  case section.state, is_dirty_cleanup(section) {
    Idle, False -> html.div([], [])
    _, _ ->
      html.span([attribute.class(cleanup_status_badge_class(section))], [
        html.text(cleanup_status_badge_text(section)),
      ])
  }
}

fn cleanup_status_badge_text(section: CleanupSection) -> String {
  case section.state {
    SaveError(_) -> "Error"
    Saving -> "Saving"
    Saved -> "Saved"
    Idle ->
      case is_dirty_cleanup(section) {
        True -> "Unsaved"
        False -> ""
      }
  }
}

fn cleanup_status_badge_class(section: CleanupSection) -> String {
  case section.state {
    SaveError(_) -> "admin-page__version admin-page__version--error"
    Saving -> "admin-page__version"
    Saved -> "admin-page__version admin-page__version--success"
    Idle ->
      case is_dirty_cleanup(section) {
        True -> "admin-page__version admin-page__version--dirty"
        False -> "admin-page__version"
      }
  }
}

fn cleanup_section_message(section: CleanupSection) -> Element(Msg) {
  section_state_message(section.state)
}

fn section_state_message(state: SectionState) -> Element(Msg) {
  let message = case state {
    SaveError(message) ->
      option.Some(#(
        "admin-page__policy-status admin-page__policy-status--error",
        message,
      ))
    Saving -> option.Some(#("admin-page__policy-status", "Saving changes..."))
    Saved -> option.Some(#("admin-page__policy-status", "Config saved."))
    Idle -> option.None
  }

  case message {
    option.Some(#(class_name, text)) ->
      html.p([attribute.class(class_name)], [html.text(text)])
    option.None -> html.div([], [])
  }
}

fn load_debug_config() -> Effect(Msg) {
  api.get_admin_debug_config(DebugLoaded)
}

fn load_auth_config() -> Effect(Msg) {
  api.get_admin_auth_config(AuthLoaded)
}

fn load_cleanup_config() -> Effect(Msg) {
  api.get_admin_cleanup_config(CleanupLoaded)
}

fn load_docker_run_config() -> Effect(Msg) {
  api.get_admin_docker_run_config(DockerRunLoaded)
}

fn auth_fields_from_response(
  response: auth_config_dto.AuthConfigResponse,
) -> AuthFields {
  AuthFields(
    login_token_max_age: int.to_string(response.login_token_max_age),
    session_token_max_age: int.to_string(response.session_token_max_age),
    session_cookie_max_age: int.to_string(response.session_cookie_max_age),
  )
}

fn debug_fields_from_response(
  response: debug_config_dto.DebugConfigResponse,
) -> DebugFields {
  DebugFields(enabled: response.enabled)
}

fn cleanup_fields_from_response(
  response: cleanup_config_dto.CleanupConfigResponse,
) -> CleanupFields {
  CleanupFields(
    api_log_retention_days: int.to_string(response.api_log_retention_days),
    page_log_retention_days: int.to_string(response.page_log_retention_days),
    pageview_log_retention_days: int.to_string(
      response.pageview_log_retention_days,
    ),
    run_log_retention_days: int.to_string(response.run_log_retention_days),
    job_log_retention_days: int.to_string(response.job_log_retention_days),
    jobs_retention_days: int.to_string(response.jobs_retention_days),
    login_tokens_retention_days: int.to_string(
      response.login_tokens_retention_days,
    ),
    user_actions_retention_days: int.to_string(
      response.user_actions_retention_days,
    ),
  )
}

fn docker_run_fields_from_response(
  response: docker_run_config_dto.DockerRunConfigResponse,
) -> DockerRunFields {
  DockerRunFields(
    base_url: response.base_url,
    access_token: response.access_token,
  )
}

fn validate_docker_run_fields(
  fields: DockerRunFields,
) -> Result(docker_run_config_dto.UpsertDockerRunConfigRequest, String) {
  case fields.base_url, fields.access_token {
    "", _ -> Error("Base URL must not be empty.")
    _, "" -> Error("Access token must not be empty.")
    _, _ ->
      Ok(docker_run_config_dto.UpsertDockerRunConfigRequest(
        base_url: fields.base_url,
        access_token: fields.access_token,
      ))
  }
}

fn is_dirty(section: DockerRunSection) -> Bool {
  section.saved != section.draft
}

fn is_dirty_debug(section: DebugSection) -> Bool {
  section.saved != section.draft
}

fn is_dirty_auth(section: AuthSection) -> Bool {
  section.saved != section.draft
}

fn is_dirty_cleanup(section: CleanupSection) -> Bool {
  section.saved != section.draft
}

fn validate_auth_fields(
  fields: AuthFields,
) -> Result(auth_config_dto.UpsertAuthConfigRequest, String) {
  use login_token_max_age <- result.try(parse_positive_int(
    fields.login_token_max_age,
    "Login token max age must be a positive integer.",
  ))
  use session_token_max_age <- result.try(parse_positive_int(
    fields.session_token_max_age,
    "Session token max age must be a positive integer.",
  ))
  use session_cookie_max_age <- result.try(parse_positive_int(
    fields.session_cookie_max_age,
    "Session cookie max age must be a positive integer.",
  ))

  Ok(auth_config_dto.UpsertAuthConfigRequest(
    login_token_max_age: login_token_max_age,
    session_token_max_age: session_token_max_age,
    session_cookie_max_age: session_cookie_max_age,
  ))
}

fn validate_cleanup_fields(
  fields: CleanupFields,
) -> Result(cleanup_config_dto.UpsertCleanupConfigRequest, String) {
  use api_log_retention_days <- result.try(parse_positive_int(
    fields.api_log_retention_days,
    "API log retention must be a positive integer.",
  ))
  use page_log_retention_days <- result.try(parse_positive_int(
    fields.page_log_retention_days,
    "Page log retention must be a positive integer.",
  ))
  use pageview_log_retention_days <- result.try(parse_positive_int(
    fields.pageview_log_retention_days,
    "Pageview log retention must be a positive integer.",
  ))
  use run_log_retention_days <- result.try(parse_positive_int(
    fields.run_log_retention_days,
    "Run log retention must be a positive integer.",
  ))
  use job_log_retention_days <- result.try(parse_positive_int(
    fields.job_log_retention_days,
    "Job log retention must be a positive integer.",
  ))
  use jobs_retention_days <- result.try(parse_positive_int(
    fields.jobs_retention_days,
    "Jobs retention must be a positive integer.",
  ))
  use login_tokens_retention_days <- result.try(parse_positive_int(
    fields.login_tokens_retention_days,
    "Login token retention must be a positive integer.",
  ))
  use user_actions_retention_days <- result.try(parse_positive_int(
    fields.user_actions_retention_days,
    "User actions retention must be a positive integer.",
  ))

  Ok(cleanup_config_dto.UpsertCleanupConfigRequest(
    api_log_retention_days: api_log_retention_days,
    page_log_retention_days: page_log_retention_days,
    pageview_log_retention_days: pageview_log_retention_days,
    run_log_retention_days: run_log_retention_days,
    job_log_retention_days: job_log_retention_days,
    jobs_retention_days: jobs_retention_days,
    login_tokens_retention_days: login_tokens_retention_days,
    user_actions_retention_days: user_actions_retention_days,
  ))
}

fn parse_positive_int(
  value: String,
  error_message: String,
) -> Result(Int, String) {
  case int.parse(string.trim(value)) {
    Ok(parsed) if parsed > 0 -> Ok(parsed)
    _ -> Error(error_message)
  }
}

fn empty_auth_section() -> AuthSection {
  let fields = empty_auth_fields()
  AuthSection(saved: fields, draft: fields, state: Idle)
}

fn empty_debug_section() -> DebugSection {
  let fields = empty_debug_fields()
  DebugSection(saved: fields, draft: fields, state: Idle)
}

fn empty_debug_fields() -> DebugFields {
  DebugFields(enabled: False)
}

fn empty_auth_fields() -> AuthFields {
  AuthFields(
    login_token_max_age: "",
    session_token_max_age: "",
    session_cookie_max_age: "",
  )
}

fn empty_cleanup_section() -> CleanupSection {
  let fields = empty_cleanup_fields()
  CleanupSection(saved: fields, draft: fields, state: Idle)
}

fn empty_cleanup_fields() -> CleanupFields {
  CleanupFields(
    api_log_retention_days: "",
    page_log_retention_days: "",
    pageview_log_retention_days: "",
    run_log_retention_days: "",
    job_log_retention_days: "",
    jobs_retention_days: "",
    login_tokens_retention_days: "",
    user_actions_retention_days: "",
  )
}

fn empty_docker_run_section() -> DockerRunSection {
  let fields = empty_docker_run_fields()
  DockerRunSection(saved: fields, draft: fields, state: Idle)
}

fn empty_docker_run_fields() -> DockerRunFields {
  DockerRunFields(base_url: "", access_token: "")
}

fn loaded_status(model: Model) -> Status {
  case
    model.debug_loaded
    && model.auth_loaded
    && model.cleanup_loaded
    && model.docker_run_loaded
  {
    True -> Ready
    False -> Loading
  }
}
