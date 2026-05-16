import gleam/int
import gleam/option
import gleam/result
import glot_core/admin/auth_config_dto
import glot_core/admin/availability_config_dto
import glot_core/admin/cleanup_config_dto
import glot_core/admin/debug_config_dto
import glot_core/admin/docker_run_config_dto
import glot_core/availability_mode
import glot_frontend/admin_format
import glot_frontend/admin_ui
import glot_frontend/api
import glot_frontend/mutation
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub type Model {
  Model(
    status: Status,
    debug: DebugSection,
    availability: AvailabilitySection,
    auth: AuthSection,
    cleanup: CleanupSection,
    docker_run: DockerRunSection,
    debug_loaded: Bool,
    availability_loaded: Bool,
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
    state: mutation.MutationState,
  )
}

pub type DockerRunFields {
  DockerRunFields(base_url: String, access_token: String)
}

pub type DebugSection {
  DebugSection(
    saved: DebugFields,
    draft: DebugFields,
    state: mutation.MutationState,
  )
}

pub type AvailabilitySection {
  AvailabilitySection(
    saved: AvailabilityFields,
    draft: AvailabilityFields,
    state: mutation.MutationState,
  )
}

pub type DebugFields {
  DebugFields(enabled: Bool)
}

pub type AvailabilityFields {
  AvailabilityFields(
    mode: availability_mode.AvailabilityMode,
    message: String,
    retry_after_seconds: String,
  )
}

pub type AuthSection {
  AuthSection(
    saved: AuthFields,
    draft: AuthFields,
    state: mutation.MutationState,
  )
}

pub type AuthFields {
  AuthFields(
    login_token_max_age: String,
    session_token_max_age: String,
    session_cookie_max_age: String,
    session_refresh_interval_seconds: String,
    session_previous_token_grace_seconds: String,
    session_heartbeat_interval_seconds: String,
  )
}

pub type CleanupSection {
  CleanupSection(
    saved: CleanupFields,
    draft: CleanupFields,
    state: mutation.MutationState,
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

pub type Msg {
  DebugLoaded(api.ApiResponse(debug_config_dto.DebugConfigResponse))
  DebugToggleClicked
  DebugResetClicked
  DebugSaveClicked
  DebugSaveFinished(api.ApiResponse(debug_config_dto.DebugConfigResponse))
  AvailabilityLoaded(
    api.ApiResponse(availability_config_dto.AvailabilityConfigResponse),
  )
  AvailabilityModeSelected(availability_mode.AvailabilityMode)
  AvailabilityMessageChanged(String)
  AvailabilityRetryAfterSecondsChanged(String)
  AvailabilityResetClicked
  AvailabilitySaveClicked
  AvailabilitySaveFinished(
    api.ApiResponse(availability_config_dto.AvailabilityConfigResponse),
  )
  AuthLoaded(api.ApiResponse(auth_config_dto.AuthConfigResponse))
  AuthLoginTokenMaxAgeChanged(String)
  AuthSessionTokenMaxAgeChanged(String)
  AuthSessionCookieMaxAgeChanged(String)
  AuthSessionRefreshIntervalSecondsChanged(String)
  AuthSessionPreviousTokenGraceSecondsChanged(String)
  AuthSessionHeartbeatIntervalSecondsChanged(String)
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
      availability: empty_availability_section(),
      auth: empty_auth_section(),
      cleanup: empty_cleanup_section(),
      docker_run: empty_docker_run_section(),
      debug_loaded: False,
      availability_loaded: False,
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
        load_availability_config(),
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
              debug: DebugSection(
                saved: fields,
                draft: fields,
                state: mutation.Idle,
              ),
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
          state: mutation.Idle,
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
          state: mutation.Idle,
        ),
      ),
      effect.none(),
    )

    DebugSaveClicked -> #(
      Model(..model, debug: DebugSection(..model.debug, state: mutation.Saving)),
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
              debug: DebugSection(
                saved: fields,
                draft: fields,
                state: mutation.Saved,
              ),
            ),
            effect.none(),
          )
        }
        api.ApiFailure(error) -> #(
          Model(
            ..model,
            debug: DebugSection(
              ..model.debug,
              state: mutation.SaveError(error.message),
            ),
          ),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(
            ..model,
            debug: DebugSection(
              ..model.debug,
              state: mutation.SaveError("Could not save debug config."),
            ),
          ),
          effect.none(),
        )
      }

    AvailabilityLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> {
          let fields = availability_fields_from_response(response)
          let next_model =
            Model(
              ..model,
              availability: AvailabilitySection(
                saved: fields,
                draft: fields,
                state: mutation.Idle,
              ),
              availability_loaded: True,
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
          Model(
            ..model,
            status: LoadError("Could not load availability config."),
          ),
          effect.none(),
        )
      }

    AvailabilityModeSelected(mode) -> #(
      Model(
        ..model,
        availability: AvailabilitySection(
          ..model.availability,
          draft: AvailabilityFields(..model.availability.draft, mode: mode),
          state: mutation.Idle,
        ),
      ),
      effect.none(),
    )

    AvailabilityMessageChanged(value) -> #(
      Model(
        ..model,
        availability: AvailabilitySection(
          ..model.availability,
          draft: AvailabilityFields(..model.availability.draft, message: value),
          state: mutation.Idle,
        ),
      ),
      effect.none(),
    )

    AvailabilityRetryAfterSecondsChanged(value) -> #(
      Model(
        ..model,
        availability: AvailabilitySection(
          ..model.availability,
          draft: AvailabilityFields(
            ..model.availability.draft,
            retry_after_seconds: value,
          ),
          state: mutation.Idle,
        ),
      ),
      effect.none(),
    )

    AvailabilityResetClicked -> #(
      Model(
        ..model,
        availability: AvailabilitySection(
          ..model.availability,
          draft: model.availability.saved,
          state: mutation.Idle,
        ),
      ),
      effect.none(),
    )

    AvailabilitySaveClicked ->
      case validate_availability_fields(model.availability.draft) {
        Error(message) -> #(
          Model(
            ..model,
            availability: AvailabilitySection(
              ..model.availability,
              state: mutation.SaveError(message),
            ),
          ),
          effect.none(),
        )
        Ok(request) -> #(
          Model(
            ..model,
            availability: AvailabilitySection(
              ..model.availability,
              state: mutation.Saving,
            ),
          ),
          api.upsert_admin_availability_config(
            request,
            AvailabilitySaveFinished,
          ),
        )
      }

    AvailabilitySaveFinished(result) ->
      case result {
        api.ApiSuccess(response) -> {
          let fields = availability_fields_from_response(response)
          #(
            Model(
              ..model,
              availability: AvailabilitySection(
                saved: fields,
                draft: fields,
                state: mutation.Saved,
              ),
            ),
            effect.none(),
          )
        }
        api.ApiFailure(error) -> #(
          Model(
            ..model,
            availability: AvailabilitySection(
              ..model.availability,
              state: mutation.SaveError(error.message),
            ),
          ),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(
            ..model,
            availability: AvailabilitySection(
              ..model.availability,
              state: mutation.SaveError("Could not save availability config."),
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
              auth: AuthSection(
                saved: fields,
                draft: fields,
                state: mutation.Idle,
              ),
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
          state: mutation.Idle,
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
          state: mutation.Idle,
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
          state: mutation.Idle,
        ),
      ),
      effect.none(),
    )

    AuthSessionRefreshIntervalSecondsChanged(value) -> #(
      Model(
        ..model,
        auth: AuthSection(
          ..model.auth,
          draft: AuthFields(
            ..model.auth.draft,
            session_refresh_interval_seconds: value,
          ),
          state: mutation.Idle,
        ),
      ),
      effect.none(),
    )

    AuthSessionPreviousTokenGraceSecondsChanged(value) -> #(
      Model(
        ..model,
        auth: AuthSection(
          ..model.auth,
          draft: AuthFields(
            ..model.auth.draft,
            session_previous_token_grace_seconds: value,
          ),
          state: mutation.Idle,
        ),
      ),
      effect.none(),
    )

    AuthSessionHeartbeatIntervalSecondsChanged(value) -> #(
      Model(
        ..model,
        auth: AuthSection(
          ..model.auth,
          draft: AuthFields(
            ..model.auth.draft,
            session_heartbeat_interval_seconds: value,
          ),
          state: mutation.Idle,
        ),
      ),
      effect.none(),
    )

    AuthResetClicked -> #(
      Model(
        ..model,
        auth: AuthSection(
          ..model.auth,
          draft: model.auth.saved,
          state: mutation.Idle,
        ),
      ),
      effect.none(),
    )

    AuthSaveClicked ->
      case validate_auth_fields(model.auth.draft) {
        Error(message) -> #(
          Model(
            ..model,
            auth: AuthSection(..model.auth, state: mutation.SaveError(message)),
          ),
          effect.none(),
        )
        Ok(request) -> #(
          Model(
            ..model,
            auth: AuthSection(..model.auth, state: mutation.Saving),
          ),
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
              auth: AuthSection(
                saved: fields,
                draft: fields,
                state: mutation.Saved,
              ),
            ),
            effect.none(),
          )
        }
        api.ApiFailure(error) -> #(
          Model(
            ..model,
            auth: AuthSection(
              ..model.auth,
              state: mutation.SaveError(error.message),
            ),
          ),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(
            ..model,
            auth: AuthSection(
              ..model.auth,
              state: mutation.SaveError("Could not save auth config."),
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
              cleanup: CleanupSection(
                saved: fields,
                draft: fields,
                state: mutation.Idle,
              ),
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
          state: mutation.Idle,
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
          state: mutation.Idle,
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
          state: mutation.Idle,
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
          state: mutation.Idle,
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
          state: mutation.Idle,
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
          state: mutation.Idle,
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
          state: mutation.Idle,
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
          state: mutation.Idle,
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
          state: mutation.Idle,
        ),
      ),
      effect.none(),
    )

    CleanupSaveClicked ->
      case validate_cleanup_fields(model.cleanup.draft) {
        Error(message) -> #(
          Model(
            ..model,
            cleanup: CleanupSection(
              ..model.cleanup,
              state: mutation.SaveError(message),
            ),
          ),
          effect.none(),
        )
        Ok(request) -> #(
          Model(
            ..model,
            cleanup: CleanupSection(..model.cleanup, state: mutation.Saving),
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
                state: mutation.Saved,
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
              state: mutation.SaveError(error.message),
            ),
          ),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(
            ..model,
            cleanup: CleanupSection(
              ..model.cleanup,
              state: mutation.SaveError("Could not save cleanup config."),
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
                state: mutation.Idle,
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
          state: mutation.Idle,
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
          state: mutation.Idle,
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
          state: mutation.Idle,
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
              state: mutation.SaveError(message),
            ),
          ),
          effect.none(),
        )
        Ok(request) -> #(
          Model(
            ..model,
            docker_run: DockerRunSection(
              ..model.docker_run,
              state: mutation.Saving,
            ),
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
                state: mutation.Saved,
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
              state: mutation.SaveError(error.message),
            ),
          ),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(
            ..model,
            docker_run: DockerRunSection(
              ..model.docker_run,
              state: mutation.SaveError("Could not save docker run config."),
            ),
          ),
          effect.none(),
        )
      }
  }
}

pub fn view(model: Model) -> Element(Msg) {
  admin_ui.page(title: "App config", intro: "", content: [
    status_banner(model.status),
    html.div([attribute.class("admin-page__group")], [
      html.div([attribute.class("admin-page__section-grid")], [
        debug_section_view(model.debug, model.status),
        availability_section_view(model.availability, model.status),
        auth_section_view(model.auth, model.status),
        cleanup_section_view(model.cleanup, model.status),
        docker_run_section_view(model.docker_run, model.status),
      ]),
    ]),
  ])
}

fn auth_section_view(section: AuthSection, status: Status) -> Element(Msg) {
  let dirty = is_dirty_auth(section)

  config_section(
    title: "Auth",
    subtitle: "Controls login token and session expiration values used by the backend.",
    badge: section_badge(section.state, dirty, option.None),
    fields: html.div([attribute.class("admin-page__field-grid")], [
      admin_ui.text_input(
        label: "Login token max age",
        help: "Seconds before a login token expires.",
        value: section.draft.login_token_max_age,
        placeholder: "",
        on_input: AuthLoginTokenMaxAgeChanged,
      ),
      admin_ui.text_input(
        label: "Session token max age",
        help: "Seconds before a session becomes invalid.",
        value: section.draft.session_token_max_age,
        placeholder: "",
        on_input: AuthSessionTokenMaxAgeChanged,
      ),
      admin_ui.text_input(
        label: "Session cookie max age",
        help: "Seconds used when setting the signed session cookie.",
        value: section.draft.session_cookie_max_age,
        placeholder: "",
        on_input: AuthSessionCookieMaxAgeChanged,
      ),
      admin_ui.text_input(
        label: "Session refresh interval",
        help: "Minimum seconds between server-side session token rotations.",
        value: section.draft.session_refresh_interval_seconds,
        placeholder: "",
        on_input: AuthSessionRefreshIntervalSecondsChanged,
      ),
      admin_ui.text_input(
        label: "Previous token grace",
        help: "Seconds to accept the previous session token after rotation.",
        value: section.draft.session_previous_token_grace_seconds,
        placeholder: "",
        on_input: AuthSessionPreviousTokenGraceSecondsChanged,
      ),
      admin_ui.text_input(
        label: "Heartbeat interval",
        help: "Seconds the frontend should wait before sending the next heartbeat.",
        value: section.draft.session_heartbeat_interval_seconds,
        placeholder: "",
        on_input: AuthSessionHeartbeatIntervalSecondsChanged,
      ),
    ]),
    footer: section_footer(
      status: status,
      state: section.state,
      dirty: dirty,
      message: section_state_message(section.state, option.None),
      reset_msg: AuthResetClicked,
      save_msg: AuthSaveClicked,
    ),
  )
}

fn cleanup_section_view(
  section: CleanupSection,
  status: Status,
) -> Element(Msg) {
  let dirty = is_dirty_cleanup(section)

  config_section(
    title: "Cleanup",
    subtitle: "Controls retention windows, in days, for scheduled cleanup jobs.",
    badge: section_badge(section.state, dirty, option.None),
    fields: html.div([attribute.class("admin-page__field-grid")], [
      admin_ui.text_input(
        label: "API log retention",
        help: "Days to keep API log records.",
        value: section.draft.api_log_retention_days,
        placeholder: "",
        on_input: CleanupApiLogRetentionDaysChanged,
      ),
      admin_ui.text_input(
        label: "Page log retention",
        help: "Days to keep page log records.",
        value: section.draft.page_log_retention_days,
        placeholder: "",
        on_input: CleanupPageLogRetentionDaysChanged,
      ),
      admin_ui.text_input(
        label: "Pageview log retention",
        help: "Days to keep pageview log records.",
        value: section.draft.pageview_log_retention_days,
        placeholder: "",
        on_input: CleanupPageviewLogRetentionDaysChanged,
      ),
      admin_ui.text_input(
        label: "Run log retention",
        help: "Days to keep run log records.",
        value: section.draft.run_log_retention_days,
        placeholder: "",
        on_input: CleanupRunLogRetentionDaysChanged,
      ),
      admin_ui.text_input(
        label: "Job log retention",
        help: "Days to keep job log records.",
        value: section.draft.job_log_retention_days,
        placeholder: "",
        on_input: CleanupJobLogRetentionDaysChanged,
      ),
      admin_ui.text_input(
        label: "Jobs retention",
        help: "Days to keep completed jobs.",
        value: section.draft.jobs_retention_days,
        placeholder: "",
        on_input: CleanupJobsRetentionDaysChanged,
      ),
      admin_ui.text_input(
        label: "Login token retention",
        help: "Days to keep used or expired login tokens.",
        value: section.draft.login_tokens_retention_days,
        placeholder: "",
        on_input: CleanupLoginTokensRetentionDaysChanged,
      ),
      admin_ui.text_input(
        label: "User actions retention",
        help: "Days to keep user action audit records.",
        value: section.draft.user_actions_retention_days,
        placeholder: "",
        on_input: CleanupUserActionsRetentionDaysChanged,
      ),
    ]),
    footer: section_footer(
      status: status,
      state: section.state,
      dirty: dirty,
      message: section_state_message(section.state, option.None),
      reset_msg: CleanupResetClicked,
      save_msg: CleanupSaveClicked,
    ),
  )
}

fn status_banner(status: Status) -> Element(Msg) {
  case status {
    NotLoaded | Ready -> admin_ui.blank_status()
    Loading -> admin_ui.status("Loading configuration...")
    LoadError(message) -> admin_ui.error_status(message)
  }
}

fn debug_section_view(section: DebugSection, status: Status) -> Element(Msg) {
  let dirty = is_dirty_debug(section)

  config_section(
    title: "Debug",
    subtitle: "Controls whether backend debug log fields are collected into API and page logs.",
    badge: section_badge(section.state, dirty, option.None),
    fields: html.div([attribute.class("admin-page__field-grid")], [
      html.div([attribute.class("admin-page__field")], [
        html.span([attribute.class("admin-page__field-label")], [
          html.text("Debug logging"),
        ]),
        admin_ui.secondary_button(
          [
            attribute.type_("button"),
            attribute.disabled(
              status != Ready || mutation.is_saving(section.state),
            ),
            event.on_click(DebugToggleClicked),
          ],
          case section.draft.enabled {
            True -> "Enabled"
            False -> "Disabled"
          },
        ),
        html.span([attribute.class("admin-page__field-help")], [
          html.text(
            "When enabled, debug fields are persisted with API logs. Toggle to change the draft value.",
          ),
        ]),
      ]),
    ]),
    footer: section_footer(
      status: status,
      state: section.state,
      dirty: dirty,
      message: section_state_message(section.state, option.None),
      reset_msg: DebugResetClicked,
      save_msg: DebugSaveClicked,
    ),
  )
}

fn availability_section_view(
  section: AvailabilitySection,
  status: Status,
) -> Element(Msg) {
  let dirty = is_dirty_availability(section)

  config_section(
    title: "Availability",
    subtitle: "Controls whether the app is normal, read-only, or unavailable to non-admin traffic.",
    badge: section_badge(section.state, dirty, option.None),
    fields: html.div([attribute.class("admin-page__field-grid")], [
      html.div([attribute.class("admin-page__field")], [
        html.span([attribute.class("admin-page__field-label")], [
          html.text("Mode"),
        ]),
        html.div([attribute.class("admin-page__actions")], [
          availability_mode_button(
            "Normal",
            availability_mode.NormalMode,
            section,
            status,
          ),
          availability_mode_button(
            "Read only",
            availability_mode.ReadOnlyMode,
            section,
            status,
          ),
          availability_mode_button(
            "Maintenance",
            availability_mode.MaintenanceMode,
            section,
            status,
          ),
        ]),
        html.span([attribute.class("admin-page__field-help")], [
          html.text(
            "Admin routes and admin actions remain available. Read-only blocks writes. Maintenance blocks most public traffic.",
          ),
        ]),
      ]),
      admin_ui.textarea_input(
        label: "Message",
        help: "Shown in 503 responses for unavailable pages and APIs.",
        value: section.draft.message,
        rows: 3,
        on_input: AvailabilityMessageChanged,
      ),
      admin_ui.text_input(
        label: "Retry-After seconds",
        help: "Optional integer. Leave blank to omit the Retry-After header.",
        value: section.draft.retry_after_seconds,
        placeholder: "300",
        on_input: AvailabilityRetryAfterSecondsChanged,
      ),
    ]),
    footer: section_footer(
      status: status,
      state: section.state,
      dirty: dirty,
      message: section_state_message(section.state, option.None),
      reset_msg: AvailabilityResetClicked,
      save_msg: AvailabilitySaveClicked,
    ),
  )
}

fn availability_mode_button(
  label: String,
  mode: availability_mode.AvailabilityMode,
  section: AvailabilitySection,
  status: Status,
) -> Element(Msg) {
  let is_selected = section.draft.mode == mode
  let class_name = case is_selected {
    True -> admin_ui.primary_button_class()
    False -> admin_ui.secondary_button_class()
  }

  html.button(
    [
      attribute.type_("button"),
      attribute.class(class_name),
      attribute.disabled(status != Ready || mutation.is_saving(section.state)),
      event.on_click(AvailabilityModeSelected(mode)),
    ],
    [html.text(label)],
  )
}

fn docker_run_section_view(
  section: DockerRunSection,
  status: Status,
) -> Element(Msg) {
  let dirty = is_dirty(section)
  let is_empty = section.saved == empty_docker_run_fields()

  config_section(
    title: "Docker run",
    subtitle: "Controls the base URL and access token used when the backend calls the docker-run service.",
    badge: section_badge(section.state, dirty, idle_text(is_empty)),
    fields: html.div([attribute.class("admin-page__field-grid")], [
      admin_ui.text_input(
        label: "Base URL",
        help: "Example: https://docker-run.internal",
        value: section.draft.base_url,
        placeholder: "",
        on_input: DockerRunBaseUrlChanged,
      ),
      admin_ui.text_input(
        label: "Access token",
        help: "Stored as a regular app config value.",
        value: section.draft.access_token,
        placeholder: "",
        on_input: DockerRunAccessTokenChanged,
      ),
    ]),
    footer: section_footer(
      status: status,
      state: section.state,
      dirty: dirty,
      message: section_state_message(
        section.state,
        idle_message(
          is_empty,
          "This section is empty until you save initial values.",
        ),
      ),
      reset_msg: DockerRunResetClicked,
      save_msg: DockerRunSaveClicked,
    ),
  )
}

fn config_section(
  title title: String,
  subtitle subtitle: String,
  badge badge: Element(Msg),
  fields fields: Element(Msg),
  footer footer: Element(Msg),
) -> Element(Msg) {
  html.article(
    [attribute.class("admin-page__policy admin-page__policy--config")],
    [
      html.div([attribute.class("admin-page__policy-header")], [
        html.div([], [
          html.h3([attribute.class("admin-page__policy-title")], [
            html.text(title),
          ]),
          html.p([attribute.class("admin-page__policy-subtitle")], [
            html.text(subtitle),
          ]),
        ]),
        html.div([attribute.class("admin-page__policy-header-actions")], [badge]),
      ]),
      fields,
      footer,
    ],
  )
}

fn section_footer(
  status status: Status,
  state state: mutation.MutationState,
  dirty dirty: Bool,
  message message: Element(Msg),
  reset_msg reset_msg: Msg,
  save_msg save_msg: Msg,
) -> Element(Msg) {
  let save_disabled = status != Ready || mutation.is_saving(state) || !dirty

  html.div([attribute.class("admin-page__policy-footer")], [
    message,
    html.div([attribute.class("admin-page__actions")], [
      admin_ui.secondary_button(
        [
          attribute.type_("button"),
          attribute.disabled(mutation.is_saving(state) || !dirty),
          event.on_click(reset_msg),
        ],
        "Reset",
      ),
      html.button(
        [
          attribute.type_("button"),
          attribute.class("admin-page__button"),
          attribute.disabled(save_disabled),
          event.on_click(save_msg),
        ],
        [html.text(save_button_text(state))],
      ),
    ]),
  ])
}

fn section_badge(
  state: mutation.MutationState,
  dirty: Bool,
  idle_text: option.Option(String),
) -> Element(Msg) {
  case section_badge_copy(state, dirty, idle_text) {
    option.Some(text) ->
      html.span([attribute.class(section_badge_class(state, dirty))], [
        html.text(text),
      ])
    option.None -> html.div([], [])
  }
}

fn section_badge_copy(
  state: mutation.MutationState,
  dirty: Bool,
  idle_text: option.Option(String),
) -> option.Option(String) {
  case state {
    mutation.SaveError(_) -> option.Some("Error")
    mutation.Saving -> option.Some("Saving")
    mutation.Saved -> option.Some("Saved")
    mutation.Idle ->
      case dirty {
        True -> option.Some("Unsaved")
        False -> idle_text
      }
  }
}

fn section_badge_class(state: mutation.MutationState, dirty: Bool) -> String {
  case state {
    mutation.SaveError(_) -> "admin-page__version admin-page__version--error"
    mutation.Saving -> "admin-page__version"
    mutation.Saved -> "admin-page__version admin-page__version--success"
    mutation.Idle ->
      case dirty {
        True -> "admin-page__version admin-page__version--dirty"
        False -> "admin-page__version"
      }
  }
}

fn section_state_message(
  state: mutation.MutationState,
  idle_message: option.Option(String),
) -> Element(Msg) {
  let message = case state {
    mutation.SaveError(message) ->
      option.Some(#(
        "admin-page__policy-status admin-page__policy-status--error",
        message,
      ))
    mutation.Saving ->
      option.Some(#("admin-page__policy-status", "Saving changes..."))
    mutation.Saved ->
      option.Some(#("admin-page__policy-status", "Config saved."))
    mutation.Idle ->
      idle_message
      |> option.map(fn(message) { #("admin-page__policy-status", message) })
  }

  case message {
    option.Some(#(class_name, text)) ->
      html.p([attribute.class(class_name)], [html.text(text)])
    option.None -> html.div([], [])
  }
}

fn idle_text(is_empty: Bool) -> option.Option(String) {
  case is_empty {
    True -> option.Some("Not configured")
    False -> option.None
  }
}

fn idle_message(is_empty: Bool, message: String) -> option.Option(String) {
  case is_empty {
    True -> option.Some(message)
    False -> option.None
  }
}

fn save_button_text(state: mutation.MutationState) -> String {
  case state {
    mutation.Saving -> "Saving..."
    mutation.Idle | mutation.Saved | mutation.SaveError(_) -> "Save"
  }
}

fn load_debug_config() -> Effect(Msg) {
  api.get_admin_debug_config(DebugLoaded)
}

fn load_availability_config() -> Effect(Msg) {
  api.get_admin_availability_config(AvailabilityLoaded)
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
    session_refresh_interval_seconds: int.to_string(
      response.session_refresh_interval_seconds,
    ),
    session_previous_token_grace_seconds: int.to_string(
      response.session_previous_token_grace_seconds,
    ),
    session_heartbeat_interval_seconds: int.to_string(
      response.session_heartbeat_interval_seconds,
    ),
  )
}

fn debug_fields_from_response(
  response: debug_config_dto.DebugConfigResponse,
) -> DebugFields {
  DebugFields(enabled: response.enabled)
}

fn availability_fields_from_response(
  response: availability_config_dto.AvailabilityConfigResponse,
) -> AvailabilityFields {
  AvailabilityFields(
    mode: response.mode,
    message: response.message,
    retry_after_seconds: option.map(response.retry_after_seconds, int.to_string)
      |> option.unwrap(""),
  )
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

fn is_dirty_availability(section: AvailabilitySection) -> Bool {
  section.saved != section.draft
}

fn validate_availability_fields(
  fields: AvailabilityFields,
) -> Result(availability_config_dto.UpsertAvailabilityConfigRequest, String) {
  let retry_after_seconds = case fields.retry_after_seconds {
    "" -> Ok(option.None)
    value ->
      admin_format.parse_positive_int_with_error(
        value,
        "Retry-After seconds must be a positive integer.",
      )
      |> result.map(option.Some)
  }

  use retry_after_seconds <- result.try(retry_after_seconds)

  case fields.message {
    "" -> Error("Availability message must not be empty.")
    _ ->
      Ok(availability_config_dto.UpsertAvailabilityConfigRequest(
        mode: fields.mode,
        message: fields.message,
        retry_after_seconds: retry_after_seconds,
      ))
  }
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
  use login_token_max_age <- result.try(
    admin_format.parse_positive_int_with_error(
      fields.login_token_max_age,
      "Login token max age must be a positive integer.",
    ),
  )
  use session_token_max_age <- result.try(
    admin_format.parse_positive_int_with_error(
      fields.session_token_max_age,
      "Session token max age must be a positive integer.",
    ),
  )
  use session_cookie_max_age <- result.try(
    admin_format.parse_positive_int_with_error(
      fields.session_cookie_max_age,
      "Session cookie max age must be a positive integer.",
    ),
  )
  use session_refresh_interval_seconds <- result.try(
    admin_format.parse_positive_int_with_error(
      fields.session_refresh_interval_seconds,
      "Session refresh interval must be a positive integer.",
    ),
  )
  use session_previous_token_grace_seconds <- result.try(
    admin_format.parse_positive_int_with_error(
      fields.session_previous_token_grace_seconds,
      "Previous token grace must be a positive integer.",
    ),
  )
  use session_heartbeat_interval_seconds <- result.try(
    admin_format.parse_positive_int_with_error(
      fields.session_heartbeat_interval_seconds,
      "Heartbeat interval must be a positive integer.",
    ),
  )

  Ok(auth_config_dto.UpsertAuthConfigRequest(
    login_token_max_age: login_token_max_age,
    session_token_max_age: session_token_max_age,
    session_cookie_max_age: session_cookie_max_age,
    session_refresh_interval_seconds: session_refresh_interval_seconds,
    session_previous_token_grace_seconds: session_previous_token_grace_seconds,
    session_heartbeat_interval_seconds: session_heartbeat_interval_seconds,
  ))
}

fn validate_cleanup_fields(
  fields: CleanupFields,
) -> Result(cleanup_config_dto.UpsertCleanupConfigRequest, String) {
  use api_log_retention_days <- result.try(
    admin_format.parse_positive_int_with_error(
      fields.api_log_retention_days,
      "API log retention must be a positive integer.",
    ),
  )
  use page_log_retention_days <- result.try(
    admin_format.parse_positive_int_with_error(
      fields.page_log_retention_days,
      "Page log retention must be a positive integer.",
    ),
  )
  use pageview_log_retention_days <- result.try(
    admin_format.parse_positive_int_with_error(
      fields.pageview_log_retention_days,
      "Pageview log retention must be a positive integer.",
    ),
  )
  use run_log_retention_days <- result.try(
    admin_format.parse_positive_int_with_error(
      fields.run_log_retention_days,
      "Run log retention must be a positive integer.",
    ),
  )
  use job_log_retention_days <- result.try(
    admin_format.parse_positive_int_with_error(
      fields.job_log_retention_days,
      "Job log retention must be a positive integer.",
    ),
  )
  use jobs_retention_days <- result.try(
    admin_format.parse_positive_int_with_error(
      fields.jobs_retention_days,
      "Jobs retention must be a positive integer.",
    ),
  )
  use login_tokens_retention_days <- result.try(
    admin_format.parse_positive_int_with_error(
      fields.login_tokens_retention_days,
      "Login token retention must be a positive integer.",
    ),
  )
  use user_actions_retention_days <- result.try(
    admin_format.parse_positive_int_with_error(
      fields.user_actions_retention_days,
      "User actions retention must be a positive integer.",
    ),
  )

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

fn empty_auth_section() -> AuthSection {
  let fields = empty_auth_fields()
  AuthSection(saved: fields, draft: fields, state: mutation.Idle)
}

fn empty_debug_section() -> DebugSection {
  let fields = empty_debug_fields()
  DebugSection(saved: fields, draft: fields, state: mutation.Idle)
}

fn empty_availability_section() -> AvailabilitySection {
  let fields = empty_availability_fields()
  AvailabilitySection(saved: fields, draft: fields, state: mutation.Idle)
}

fn empty_debug_fields() -> DebugFields {
  DebugFields(enabled: False)
}

fn empty_availability_fields() -> AvailabilityFields {
  AvailabilityFields(
    mode: availability_mode.NormalMode,
    message: "glot.io is temporarily unavailable right now.",
    retry_after_seconds: "",
  )
}

fn empty_auth_fields() -> AuthFields {
  AuthFields(
    login_token_max_age: "",
    session_token_max_age: "",
    session_cookie_max_age: "",
    session_refresh_interval_seconds: "",
    session_previous_token_grace_seconds: "",
    session_heartbeat_interval_seconds: "",
  )
}

fn empty_cleanup_section() -> CleanupSection {
  let fields = empty_cleanup_fields()
  CleanupSection(saved: fields, draft: fields, state: mutation.Idle)
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
  DockerRunSection(saved: fields, draft: fields, state: mutation.Idle)
}

fn empty_docker_run_fields() -> DockerRunFields {
  DockerRunFields(base_url: "", access_token: "")
}

fn loaded_status(model: Model) -> Status {
  case
    model.debug_loaded
    && model.availability_loaded
    && model.auth_loaded
    && model.cleanup_loaded
    && model.docker_run_loaded
  {
    True -> Ready
    False -> Loading
  }
}
