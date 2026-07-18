import gleam/int
import gleam/option
import gleam/result
import glot_core/admin/auth_config_dto
import glot_core/admin/availability_config_dto
import glot_core/admin/cleanup_config_dto
import glot_core/admin/cloudflare_config_dto
import glot_core/admin/debug_config_dto
import glot_core/admin/docker_run_config_dto
import glot_core/admin/email_config_dto
import glot_core/admin/language_version_cache_worker_config_dto
import glot_core/admin/log_worker_config_dto
import glot_core/admin/passkey_config_dto
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
    passkey: PasskeySection,
    cleanup: CleanupSection,
    log_worker: LogWorkerSection,
    language_version_cache_worker: LanguageVersionCacheWorkerSection,
    docker_run: DockerRunSection,
    cloudflare: CloudflareSection,
    email: EmailSection,
    debug_loaded: Bool,
    availability_loaded: Bool,
    auth_loaded: Bool,
    passkey_loaded: Bool,
    cleanup_loaded: Bool,
    log_worker_loaded: Bool,
    language_version_cache_worker_loaded: Bool,
    docker_run_loaded: Bool,
    cloudflare_loaded: Bool,
    email_loaded: Bool,
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
  DockerRunFields(
    base_url: String,
    access_token: String,
    default_timeout_ms: String,
  )
}

pub type CloudflareSection {
  CloudflareSection(
    saved: CloudflareFields,
    draft: CloudflareFields,
    state: mutation.MutationState,
  )
}

pub type CloudflareFields {
  CloudflareFields(account_id: String, api_token: String)
}

pub type EmailSection {
  EmailSection(
    saved: EmailFields,
    draft: EmailFields,
    state: mutation.MutationState,
  )
}

pub type EmailFields {
  EmailFields(
    from_address: String,
    from_name: String,
    contact_address: String,
    default_timeout_ms: String,
  )
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

pub type PasskeySection {
  PasskeySection(
    saved: PasskeyFields,
    draft: PasskeyFields,
    state: mutation.MutationState,
  )
}

pub type AuthFields {
  AuthFields(
    login_token_max_age: String,
    session_token_max_age: String,
    session_idle_timeout_seconds: String,
    session_cookie_max_age: String,
    session_refresh_interval_seconds: String,
    session_previous_token_grace_seconds: String,
    session_heartbeat_interval_seconds: String,
  )
}

pub type PasskeyFields {
  PasskeyFields(
    origin: String,
    rp_id: String,
    challenge_timeout_seconds: String,
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

pub type LogWorkerSection {
  LogWorkerSection(
    saved: LogWorkerFields,
    draft: LogWorkerFields,
    state: mutation.MutationState,
  )
}

pub type LogWorkerFields {
  LogWorkerFields(
    flush_interval_ms: String,
    max_batch_size: String,
    max_buffer_size: String,
  )
}

pub type LanguageVersionCacheWorkerSection {
  LanguageVersionCacheWorkerSection(
    saved: LanguageVersionCacheWorkerFields,
    draft: LanguageVersionCacheWorkerFields,
    state: mutation.MutationState,
  )
}

pub type LanguageVersionCacheWorkerFields {
  LanguageVersionCacheWorkerFields(
    refresh_interval_ms: String,
    refresh_step_delay_ms: String,
    refresh_step_jitter_ms: String,
    default_timeout_ms: String,
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
  AuthSessionIdleTimeoutSecondsChanged(String)
  AuthSessionCookieMaxAgeChanged(String)
  AuthSessionRefreshIntervalSecondsChanged(String)
  AuthSessionPreviousTokenGraceSecondsChanged(String)
  AuthSessionHeartbeatIntervalSecondsChanged(String)
  AuthResetClicked
  AuthSaveClicked
  AuthSaveFinished(api.ApiResponse(auth_config_dto.AuthConfigResponse))
  PasskeyLoaded(api.ApiResponse(passkey_config_dto.PasskeyConfigResponse))
  PasskeyOriginChanged(String)
  PasskeyRpIdChanged(String)
  PasskeyChallengeTimeoutSecondsChanged(String)
  PasskeyResetClicked
  PasskeySaveClicked
  PasskeySaveFinished(api.ApiResponse(passkey_config_dto.PasskeyConfigResponse))
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
  LogWorkerLoaded(
    api.ApiResponse(log_worker_config_dto.LogWorkerConfigResponse),
  )
  LogWorkerFlushIntervalMsChanged(String)
  LogWorkerMaxBatchSizeChanged(String)
  LogWorkerMaxBufferSizeChanged(String)
  LogWorkerResetClicked
  LogWorkerSaveClicked
  LogWorkerSaveFinished(
    api.ApiResponse(log_worker_config_dto.LogWorkerConfigResponse),
  )
  LanguageVersionCacheWorkerLoaded(
    api.ApiResponse(
      language_version_cache_worker_config_dto.LanguageVersionCacheWorkerConfigResponse,
    ),
  )
  LanguageVersionCacheWorkerRefreshIntervalMsChanged(String)
  LanguageVersionCacheWorkerRefreshStepDelayMsChanged(String)
  LanguageVersionCacheWorkerRefreshStepJitterMsChanged(String)
  LanguageVersionCacheWorkerDefaultTimeoutMsChanged(String)
  LanguageVersionCacheWorkerResetClicked
  LanguageVersionCacheWorkerSaveClicked
  LanguageVersionCacheWorkerSaveFinished(
    api.ApiResponse(
      language_version_cache_worker_config_dto.LanguageVersionCacheWorkerConfigResponse,
    ),
  )
  DockerRunLoaded(
    api.ApiResponse(docker_run_config_dto.DockerRunConfigResponse),
  )
  DockerRunBaseUrlChanged(String)
  DockerRunAccessTokenChanged(String)
  DockerRunDefaultTimeoutMsChanged(String)
  DockerRunResetClicked
  DockerRunSaveClicked
  DockerRunSaveFinished(
    api.ApiResponse(docker_run_config_dto.DockerRunConfigResponse),
  )
  CloudflareLoaded(
    api.ApiResponse(cloudflare_config_dto.CloudflareConfigResponse),
  )
  CloudflareAccountIdChanged(String)
  CloudflareApiTokenChanged(String)
  CloudflareResetClicked
  CloudflareSaveClicked
  CloudflareSaveFinished(
    api.ApiResponse(cloudflare_config_dto.CloudflareConfigResponse),
  )
  EmailLoaded(api.ApiResponse(email_config_dto.EmailConfigResponse))
  EmailFromAddressChanged(String)
  EmailFromNameChanged(String)
  EmailContactAddressChanged(String)
  EmailDefaultTimeoutMsChanged(String)
  EmailResetClicked
  EmailSaveClicked
  EmailSaveFinished(api.ApiResponse(email_config_dto.EmailConfigResponse))
}

pub fn init() -> #(Model, Effect(Msg)) {
  #(
    Model(
      status: NotLoaded,
      debug: empty_debug_section(),
      availability: empty_availability_section(),
      auth: empty_auth_section(),
      passkey: empty_passkey_section(),
      cleanup: empty_cleanup_section(),
      log_worker: empty_log_worker_section(),
      language_version_cache_worker: empty_language_version_cache_worker_section(),
      docker_run: empty_docker_run_section(),
      cloudflare: empty_cloudflare_section(),
      email: empty_email_section(),
      debug_loaded: False,
      availability_loaded: False,
      auth_loaded: False,
      passkey_loaded: False,
      cleanup_loaded: False,
      log_worker_loaded: False,
      language_version_cache_worker_loaded: False,
      docker_run_loaded: False,
      cloudflare_loaded: False,
      email_loaded: False,
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
        load_passkey_config(),
        load_cleanup_config(),
        load_log_worker_config(),
        load_language_version_cache_worker_config(),
        load_docker_run_config(),
        load_cloudflare_config(),
        load_email_config(),
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
          Model(..model, status: LoadError(api.error_message(error))),
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
              state: mutation.SaveError(api.error_message(error)),
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
          Model(..model, status: LoadError(api.error_message(error))),
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
              state: mutation.SaveError(api.error_message(error)),
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
          Model(..model, status: LoadError(api.error_message(error))),
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

    AuthSessionIdleTimeoutSecondsChanged(value) -> #(
      Model(
        ..model,
        auth: AuthSection(
          ..model.auth,
          draft: AuthFields(
            ..model.auth.draft,
            session_idle_timeout_seconds: value,
          ),
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
              state: mutation.SaveError(api.error_message(error)),
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

    PasskeyLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> {
          let fields = passkey_fields_from_response(response)
          let next_model =
            Model(
              ..model,
              passkey: PasskeySection(
                saved: fields,
                draft: fields,
                state: mutation.Idle,
              ),
              passkey_loaded: True,
            )

          #(
            Model(..next_model, status: loaded_status(next_model)),
            effect.none(),
          )
        }
        api.ApiFailure(error) -> #(
          Model(..model, status: LoadError(api.error_message(error))),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(..model, status: LoadError("Could not load passkey config.")),
          effect.none(),
        )
      }

    PasskeyOriginChanged(value) -> #(
      Model(
        ..model,
        passkey: PasskeySection(
          ..model.passkey,
          draft: PasskeyFields(..model.passkey.draft, origin: value),
          state: mutation.Idle,
        ),
      ),
      effect.none(),
    )

    PasskeyRpIdChanged(value) -> #(
      Model(
        ..model,
        passkey: PasskeySection(
          ..model.passkey,
          draft: PasskeyFields(..model.passkey.draft, rp_id: value),
          state: mutation.Idle,
        ),
      ),
      effect.none(),
    )

    PasskeyChallengeTimeoutSecondsChanged(value) -> #(
      Model(
        ..model,
        passkey: PasskeySection(
          ..model.passkey,
          draft: PasskeyFields(
            ..model.passkey.draft,
            challenge_timeout_seconds: value,
          ),
          state: mutation.Idle,
        ),
      ),
      effect.none(),
    )

    PasskeyResetClicked -> #(
      Model(
        ..model,
        passkey: PasskeySection(
          ..model.passkey,
          draft: model.passkey.saved,
          state: mutation.Idle,
        ),
      ),
      effect.none(),
    )

    PasskeySaveClicked ->
      case validate_passkey_fields(model.passkey.draft) {
        Error(message) -> #(
          Model(
            ..model,
            passkey: PasskeySection(
              ..model.passkey,
              state: mutation.SaveError(message),
            ),
          ),
          effect.none(),
        )
        Ok(request) -> #(
          Model(
            ..model,
            passkey: PasskeySection(..model.passkey, state: mutation.Saving),
          ),
          api.upsert_admin_passkey_config(request, PasskeySaveFinished),
        )
      }

    PasskeySaveFinished(result) ->
      case result {
        api.ApiSuccess(response) -> {
          let fields = passkey_fields_from_response(response)
          #(
            Model(
              ..model,
              passkey: PasskeySection(
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
            passkey: PasskeySection(
              ..model.passkey,
              state: mutation.SaveError(api.error_message(error)),
            ),
          ),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(
            ..model,
            passkey: PasskeySection(
              ..model.passkey,
              state: mutation.SaveError("Could not save passkey config."),
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
          Model(..model, status: LoadError(api.error_message(error))),
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
              state: mutation.SaveError(api.error_message(error)),
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

    LogWorkerLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> {
          let fields = log_worker_fields_from_response(response)
          let next_model =
            Model(
              ..model,
              log_worker: LogWorkerSection(
                saved: fields,
                draft: fields,
                state: mutation.Idle,
              ),
              log_worker_loaded: True,
            )

          #(
            Model(..next_model, status: loaded_status(next_model)),
            effect.none(),
          )
        }
        api.ApiFailure(error) -> #(
          Model(..model, status: LoadError(api.error_message(error))),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(..model, status: LoadError("Could not load log worker config.")),
          effect.none(),
        )
      }

    LogWorkerFlushIntervalMsChanged(value) -> #(
      Model(
        ..model,
        log_worker: LogWorkerSection(
          ..model.log_worker,
          draft: LogWorkerFields(
            ..model.log_worker.draft,
            flush_interval_ms: value,
          ),
          state: mutation.Idle,
        ),
      ),
      effect.none(),
    )

    LogWorkerMaxBatchSizeChanged(value) -> #(
      Model(
        ..model,
        log_worker: LogWorkerSection(
          ..model.log_worker,
          draft: LogWorkerFields(
            ..model.log_worker.draft,
            max_batch_size: value,
          ),
          state: mutation.Idle,
        ),
      ),
      effect.none(),
    )

    LogWorkerMaxBufferSizeChanged(value) -> #(
      Model(
        ..model,
        log_worker: LogWorkerSection(
          ..model.log_worker,
          draft: LogWorkerFields(
            ..model.log_worker.draft,
            max_buffer_size: value,
          ),
          state: mutation.Idle,
        ),
      ),
      effect.none(),
    )

    LogWorkerResetClicked -> #(
      Model(
        ..model,
        log_worker: LogWorkerSection(
          ..model.log_worker,
          draft: model.log_worker.saved,
          state: mutation.Idle,
        ),
      ),
      effect.none(),
    )

    LogWorkerSaveClicked ->
      case validate_log_worker_fields(model.log_worker.draft) {
        Error(message) -> #(
          Model(
            ..model,
            log_worker: LogWorkerSection(
              ..model.log_worker,
              state: mutation.SaveError(message),
            ),
          ),
          effect.none(),
        )
        Ok(request) -> #(
          Model(
            ..model,
            log_worker: LogWorkerSection(
              ..model.log_worker,
              state: mutation.Saving,
            ),
          ),
          api.upsert_admin_log_worker_config(request, LogWorkerSaveFinished),
        )
      }

    LogWorkerSaveFinished(result) ->
      case result {
        api.ApiSuccess(response) -> {
          let fields = log_worker_fields_from_response(response)
          #(
            Model(
              ..model,
              log_worker: LogWorkerSection(
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
            log_worker: LogWorkerSection(
              ..model.log_worker,
              state: mutation.SaveError(api.error_message(error)),
            ),
          ),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(
            ..model,
            log_worker: LogWorkerSection(
              ..model.log_worker,
              state: mutation.SaveError("Could not save log worker config."),
            ),
          ),
          effect.none(),
        )
      }

    LanguageVersionCacheWorkerLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> {
          let fields =
            language_version_cache_worker_fields_from_response(response)
          let next_model =
            Model(
              ..model,
              language_version_cache_worker: LanguageVersionCacheWorkerSection(
                saved: fields,
                draft: fields,
                state: mutation.Idle,
              ),
              language_version_cache_worker_loaded: True,
            )

          #(
            Model(..next_model, status: loaded_status(next_model)),
            effect.none(),
          )
        }
        api.ApiFailure(error) -> #(
          Model(..model, status: LoadError(api.error_message(error))),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(
            ..model,
            status: LoadError(
              "Could not load language version cache worker config.",
            ),
          ),
          effect.none(),
        )
      }

    LanguageVersionCacheWorkerRefreshIntervalMsChanged(value) -> #(
      Model(
        ..model,
        language_version_cache_worker: LanguageVersionCacheWorkerSection(
          ..model.language_version_cache_worker,
          draft: LanguageVersionCacheWorkerFields(
            ..model.language_version_cache_worker.draft,
            refresh_interval_ms: value,
          ),
          state: mutation.Idle,
        ),
      ),
      effect.none(),
    )

    LanguageVersionCacheWorkerRefreshStepDelayMsChanged(value) -> #(
      Model(
        ..model,
        language_version_cache_worker: LanguageVersionCacheWorkerSection(
          ..model.language_version_cache_worker,
          draft: LanguageVersionCacheWorkerFields(
            ..model.language_version_cache_worker.draft,
            refresh_step_delay_ms: value,
          ),
          state: mutation.Idle,
        ),
      ),
      effect.none(),
    )

    LanguageVersionCacheWorkerRefreshStepJitterMsChanged(value) -> #(
      Model(
        ..model,
        language_version_cache_worker: LanguageVersionCacheWorkerSection(
          ..model.language_version_cache_worker,
          draft: LanguageVersionCacheWorkerFields(
            ..model.language_version_cache_worker.draft,
            refresh_step_jitter_ms: value,
          ),
          state: mutation.Idle,
        ),
      ),
      effect.none(),
    )

    LanguageVersionCacheWorkerDefaultTimeoutMsChanged(value) -> #(
      Model(
        ..model,
        language_version_cache_worker: LanguageVersionCacheWorkerSection(
          ..model.language_version_cache_worker,
          draft: LanguageVersionCacheWorkerFields(
            ..model.language_version_cache_worker.draft,
            default_timeout_ms: value,
          ),
          state: mutation.Idle,
        ),
      ),
      effect.none(),
    )

    LanguageVersionCacheWorkerResetClicked -> #(
      Model(
        ..model,
        language_version_cache_worker: LanguageVersionCacheWorkerSection(
          ..model.language_version_cache_worker,
          draft: model.language_version_cache_worker.saved,
          state: mutation.Idle,
        ),
      ),
      effect.none(),
    )

    LanguageVersionCacheWorkerSaveClicked ->
      case
        validate_language_version_cache_worker_fields(
          model.language_version_cache_worker.draft,
        )
      {
        Error(message) -> #(
          Model(
            ..model,
            language_version_cache_worker: LanguageVersionCacheWorkerSection(
              ..model.language_version_cache_worker,
              state: mutation.SaveError(message),
            ),
          ),
          effect.none(),
        )
        Ok(request) -> #(
          Model(
            ..model,
            language_version_cache_worker: LanguageVersionCacheWorkerSection(
              ..model.language_version_cache_worker,
              state: mutation.Saving,
            ),
          ),
          api.upsert_admin_language_version_cache_worker_config(
            request,
            LanguageVersionCacheWorkerSaveFinished,
          ),
        )
      }

    LanguageVersionCacheWorkerSaveFinished(result) ->
      case result {
        api.ApiSuccess(response) -> {
          let fields =
            language_version_cache_worker_fields_from_response(response)
          #(
            Model(
              ..model,
              language_version_cache_worker: LanguageVersionCacheWorkerSection(
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
            language_version_cache_worker: LanguageVersionCacheWorkerSection(
              ..model.language_version_cache_worker,
              state: mutation.SaveError(api.error_message(error)),
            ),
          ),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(
            ..model,
            language_version_cache_worker: LanguageVersionCacheWorkerSection(
              ..model.language_version_cache_worker,
              state: mutation.SaveError(
                "Could not save language version cache worker config.",
              ),
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
              Model(..model, status: LoadError(api.error_message(error))),
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

    DockerRunDefaultTimeoutMsChanged(value) -> #(
      Model(
        ..model,
        docker_run: DockerRunSection(
          ..model.docker_run,
          draft: DockerRunFields(
            ..model.docker_run.draft,
            default_timeout_ms: value,
          ),
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
              state: mutation.SaveError(api.error_message(error)),
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

    CloudflareLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> {
          let fields = cloudflare_fields_from_response(response)
          let next_model =
            Model(
              ..model,
              cloudflare: CloudflareSection(
                saved: fields,
                draft: fields,
                state: mutation.Idle,
              ),
              cloudflare_loaded: True,
            )

          #(
            Model(..next_model, status: loaded_status(next_model)),
            effect.none(),
          )
        }
        api.ApiFailure(error) ->
          case error.code {
            "cloudflare_config_not_found" -> {
              let next_model =
                Model(
                  ..model,
                  cloudflare: empty_cloudflare_section(),
                  cloudflare_loaded: True,
                )

              #(
                Model(..next_model, status: loaded_status(next_model)),
                effect.none(),
              )
            }
            _ -> #(
              Model(..model, status: LoadError(api.error_message(error))),
              effect.none(),
            )
          }
        api.HttpFailure(_) -> #(
          Model(..model, status: LoadError("Could not load Cloudflare config.")),
          effect.none(),
        )
      }

    CloudflareAccountIdChanged(value) -> #(
      Model(
        ..model,
        cloudflare: CloudflareSection(
          ..model.cloudflare,
          draft: CloudflareFields(..model.cloudflare.draft, account_id: value),
          state: mutation.Idle,
        ),
      ),
      effect.none(),
    )

    CloudflareApiTokenChanged(value) -> #(
      Model(
        ..model,
        cloudflare: CloudflareSection(
          ..model.cloudflare,
          draft: CloudflareFields(..model.cloudflare.draft, api_token: value),
          state: mutation.Idle,
        ),
      ),
      effect.none(),
    )

    CloudflareResetClicked -> #(
      Model(
        ..model,
        cloudflare: CloudflareSection(
          ..model.cloudflare,
          draft: model.cloudflare.saved,
          state: mutation.Idle,
        ),
      ),
      effect.none(),
    )

    CloudflareSaveClicked ->
      case validate_cloudflare_fields(model.cloudflare.draft) {
        Error(message) -> #(
          Model(
            ..model,
            cloudflare: CloudflareSection(
              ..model.cloudflare,
              state: mutation.SaveError(message),
            ),
          ),
          effect.none(),
        )
        Ok(request) -> #(
          Model(
            ..model,
            cloudflare: CloudflareSection(
              ..model.cloudflare,
              state: mutation.Saving,
            ),
          ),
          api.upsert_admin_cloudflare_config(request, CloudflareSaveFinished),
        )
      }

    CloudflareSaveFinished(result) ->
      case result {
        api.ApiSuccess(response) -> {
          let fields = cloudflare_fields_from_response(response)
          #(
            Model(
              ..model,
              cloudflare: CloudflareSection(
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
            cloudflare: CloudflareSection(
              ..model.cloudflare,
              state: mutation.SaveError(api.error_message(error)),
            ),
          ),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(
            ..model,
            cloudflare: CloudflareSection(
              ..model.cloudflare,
              state: mutation.SaveError("Could not save Cloudflare config."),
            ),
          ),
          effect.none(),
        )
      }

    EmailLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> {
          let fields = email_fields_from_response(response)
          let next_model =
            Model(
              ..model,
              email: EmailSection(
                saved: fields,
                draft: fields,
                state: mutation.Idle,
              ),
              email_loaded: True,
            )

          #(
            Model(..next_model, status: loaded_status(next_model)),
            effect.none(),
          )
        }
        api.ApiFailure(error) -> #(
          Model(..model, status: LoadError(api.error_message(error))),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(..model, status: LoadError("Could not load email config.")),
          effect.none(),
        )
      }

    EmailFromAddressChanged(value) -> #(
      Model(
        ..model,
        email: EmailSection(
          ..model.email,
          draft: EmailFields(..model.email.draft, from_address: value),
          state: mutation.Idle,
        ),
      ),
      effect.none(),
    )

    EmailFromNameChanged(value) -> #(
      Model(
        ..model,
        email: EmailSection(
          ..model.email,
          draft: EmailFields(..model.email.draft, from_name: value),
          state: mutation.Idle,
        ),
      ),
      effect.none(),
    )

    EmailContactAddressChanged(value) -> #(
      Model(
        ..model,
        email: EmailSection(
          ..model.email,
          draft: EmailFields(..model.email.draft, contact_address: value),
          state: mutation.Idle,
        ),
      ),
      effect.none(),
    )

    EmailDefaultTimeoutMsChanged(value) -> #(
      Model(
        ..model,
        email: EmailSection(
          ..model.email,
          draft: EmailFields(..model.email.draft, default_timeout_ms: value),
          state: mutation.Idle,
        ),
      ),
      effect.none(),
    )

    EmailResetClicked -> #(
      Model(
        ..model,
        email: EmailSection(
          ..model.email,
          draft: model.email.saved,
          state: mutation.Idle,
        ),
      ),
      effect.none(),
    )

    EmailSaveClicked ->
      case validate_email_fields(model.email.draft) {
        Error(message) -> #(
          Model(
            ..model,
            email: EmailSection(
              ..model.email,
              state: mutation.SaveError(message),
            ),
          ),
          effect.none(),
        )
        Ok(request) -> #(
          Model(
            ..model,
            email: EmailSection(..model.email, state: mutation.Saving),
          ),
          api.upsert_admin_email_config(request, EmailSaveFinished),
        )
      }

    EmailSaveFinished(result) ->
      case result {
        api.ApiSuccess(response) -> {
          let fields = email_fields_from_response(response)
          #(
            Model(
              ..model,
              email: EmailSection(
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
            email: EmailSection(
              ..model.email,
              state: mutation.SaveError(api.error_message(error)),
            ),
          ),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(
            ..model,
            email: EmailSection(
              ..model.email,
              state: mutation.SaveError("Could not save email config."),
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
        passkey_section_view(model.passkey, model.status),
        cleanup_section_view(model.cleanup, model.status),
        log_worker_section_view(model.log_worker, model.status),
        language_version_cache_worker_section_view(
          model.language_version_cache_worker,
          model.status,
        ),
        docker_run_section_view(model.docker_run, model.status),
        cloudflare_section_view(model.cloudflare, model.status),
        email_section_view(model.email, model.status),
      ]),
    ]),
  ])
}

fn auth_section_view(section: AuthSection, status: Status) -> Element(Msg) {
  let dirty = is_dirty_auth(section)

  config_section(
    title: "Auth",
    subtitle: "Controls login token expiry, session lifetime, rotation policy, and frontend heartbeat cadence.",
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
        label: "Session max lifetime",
        help: "Absolute maximum seconds since creation before a session becomes invalid.",
        value: section.draft.session_token_max_age,
        placeholder: "",
        on_input: AuthSessionTokenMaxAgeChanged,
      ),
      admin_ui.text_input(
        label: "Session idle timeout",
        help: "Seconds since the last successful session heartbeat before a session becomes invalid.",
        value: section.draft.session_idle_timeout_seconds,
        placeholder: "",
        on_input: AuthSessionIdleTimeoutSecondsChanged,
      ),
      admin_ui.text_input(
        label: "Session cookie max age",
        help: "Seconds used when setting the signed session cookie.",
        value: section.draft.session_cookie_max_age,
        placeholder: "",
        on_input: AuthSessionCookieMaxAgeChanged,
      ),
      admin_ui.text_input(
        label: "Session rotation interval",
        help: "Minimum seconds between backend session token rotations.",
        value: section.draft.session_refresh_interval_seconds,
        placeholder: "",
        on_input: AuthSessionRefreshIntervalSecondsChanged,
      ),
      admin_ui.text_input(
        label: "Previous token grace window",
        help: "Seconds to keep accepting the previous session token after a rotation.",
        value: section.draft.session_previous_token_grace_seconds,
        placeholder: "",
        on_input: AuthSessionPreviousTokenGraceSecondsChanged,
      ),
      admin_ui.text_input(
        label: "Heartbeat cadence",
        help: "Seconds the frontend should wait before sending the next session heartbeat.",
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

fn passkey_section_view(
  section: PasskeySection,
  status: Status,
) -> Element(Msg) {
  let dirty = is_dirty_passkey(section)

  config_section(
    title: "Passkey",
    subtitle: "Controls the WebAuthn relying party identity and challenge lifetime used for passkey registration and login.",
    badge: section_badge(section.state, dirty, option.None),
    fields: html.div([attribute.class("admin-page__field-grid")], [
      admin_ui.text_input(
        label: "Origin",
        help: "Fully qualified site origin used for WebAuthn challenges. Example: https://glot.io",
        value: section.draft.origin,
        placeholder: "",
        on_input: PasskeyOriginChanged,
      ),
      admin_ui.text_input(
        label: "RP ID",
        help: "WebAuthn relying party ID, usually the registrable domain.",
        value: section.draft.rp_id,
        placeholder: "",
        on_input: PasskeyRpIdChanged,
      ),
      admin_ui.text_input(
        label: "Challenge timeout",
        help: "Seconds before a passkey challenge expires.",
        value: section.draft.challenge_timeout_seconds,
        placeholder: "",
        on_input: PasskeyChallengeTimeoutSecondsChanged,
      ),
    ]),
    footer: section_footer(
      status: status,
      state: section.state,
      dirty: dirty,
      message: section_state_message(section.state, option.None),
      reset_msg: PasskeyResetClicked,
      save_msg: PasskeySaveClicked,
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

fn log_worker_section_view(
  section: LogWorkerSection,
  status: Status,
) -> Element(Msg) {
  let dirty = is_dirty_log_worker(section)

  config_section(
    title: "Log worker",
    subtitle: "Controls batching and buffering for API, page, and pageview log writes.",
    badge: section_badge(section.state, dirty, option.None),
    fields: html.div([attribute.class("admin-page__field-grid")], [
      admin_ui.text_input(
        label: "Flush interval",
        help: "Milliseconds to wait before flushing a partial log batch.",
        value: section.draft.flush_interval_ms,
        placeholder: "",
        on_input: LogWorkerFlushIntervalMsChanged,
      ),
      admin_ui.text_input(
        label: "Max batch size",
        help: "Flush immediately once this many pending entries are buffered.",
        value: section.draft.max_batch_size,
        placeholder: "",
        on_input: LogWorkerMaxBatchSizeChanged,
      ),
      admin_ui.text_input(
        label: "Max buffer size",
        help: "Cap on queued log entries before the oldest pending entries are dropped.",
        value: section.draft.max_buffer_size,
        placeholder: "",
        on_input: LogWorkerMaxBufferSizeChanged,
      ),
    ]),
    footer: section_footer(
      status: status,
      state: section.state,
      dirty: dirty,
      message: section_state_message(section.state, option.None),
      reset_msg: LogWorkerResetClicked,
      save_msg: LogWorkerSaveClicked,
    ),
  )
}

fn language_version_cache_worker_section_view(
  section: LanguageVersionCacheWorkerSection,
  status: Status,
) -> Element(Msg) {
  let dirty = is_dirty_language_version_cache_worker(section)

  config_section(
    title: "Language version cache worker",
    subtitle: "Controls cache freshness, refresh pacing, and docker-run timeout for language version lookups.",
    badge: section_badge(section.state, dirty, option.None),
    fields: html.div([attribute.class("admin-page__field-grid")], [
      admin_ui.text_input(
        label: "Refresh interval",
        help: "Milliseconds before a cached language version is considered stale.",
        value: section.draft.refresh_interval_ms,
        placeholder: "",
        on_input: LanguageVersionCacheWorkerRefreshIntervalMsChanged,
      ),
      admin_ui.text_input(
        label: "Refresh step delay",
        help: "Base milliseconds between scheduled background refreshes.",
        value: section.draft.refresh_step_delay_ms,
        placeholder: "",
        on_input: LanguageVersionCacheWorkerRefreshStepDelayMsChanged,
      ),
      admin_ui.text_input(
        label: "Refresh step jitter",
        help: "Additional random milliseconds added to stagger refreshes. Can be 0.",
        value: section.draft.refresh_step_jitter_ms,
        placeholder: "",
        on_input: LanguageVersionCacheWorkerRefreshStepJitterMsChanged,
      ),
      admin_ui.text_input(
        label: "Default timeout",
        help: "Milliseconds to wait for the docker-run version check.",
        value: section.draft.default_timeout_ms,
        placeholder: "",
        on_input: LanguageVersionCacheWorkerDefaultTimeoutMsChanged,
      ),
    ]),
    footer: section_footer(
      status: status,
      state: section.state,
      dirty: dirty,
      message: section_state_message(section.state, option.None),
      reset_msg: LanguageVersionCacheWorkerResetClicked,
      save_msg: LanguageVersionCacheWorkerSaveClicked,
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
    subtitle: "Controls the base URL, access token, and fallback timeout used when the backend calls the docker-run service.",
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
      admin_ui.text_input(
        label: "Default timeout",
        help: "Fallback timeout in milliseconds when no request deadline is present.",
        value: section.draft.default_timeout_ms,
        placeholder: "",
        on_input: DockerRunDefaultTimeoutMsChanged,
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

fn cloudflare_section_view(
  section: CloudflareSection,
  status: Status,
) -> Element(Msg) {
  let dirty = is_dirty_cloudflare(section)
  let is_empty = section.saved == empty_cloudflare_fields()

  config_section(
    title: "Cloudflare",
    subtitle: "Stores the Cloudflare account and API token used for outbound email delivery.",
    badge: section_badge(section.state, dirty, idle_text(is_empty)),
    fields: html.div([attribute.class("admin-page__field-grid")], [
      admin_ui.text_input(
        label: "Account ID",
        help: "Cloudflare account identifier.",
        value: section.draft.account_id,
        placeholder: "",
        on_input: CloudflareAccountIdChanged,
      ),
      admin_ui.text_input(
        label: "API token",
        help: "Stored as a regular app config value.",
        value: section.draft.api_token,
        placeholder: "",
        on_input: CloudflareApiTokenChanged,
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
      reset_msg: CloudflareResetClicked,
      save_msg: CloudflareSaveClicked,
    ),
  )
}

fn email_section_view(section: EmailSection, status: Status) -> Element(Msg) {
  let dirty = is_dirty_email(section)
  let is_empty = section.saved == empty_email_fields()

  config_section(
    title: "Email",
    subtitle: "Stores outbound email settings and the private recipient for privacy requests.",
    badge: section_badge(section.state, dirty, idle_text(is_empty)),
    fields: html.div([attribute.class("admin-page__field-grid")], [
      admin_ui.text_input(
        label: "From address",
        help: "Sender email address used for outbound email.",
        value: section.draft.from_address,
        placeholder: "",
        on_input: EmailFromAddressChanged,
      ),
      admin_ui.text_input(
        label: "From name",
        help: "Optional sender display name.",
        value: section.draft.from_name,
        placeholder: "",
        on_input: EmailFromNameChanged,
      ),
      admin_ui.text_input(
        label: "Contact address",
        help: "Optional private recipient for submissions from the public contact form. This value is never returned by the public API.",
        value: section.draft.contact_address,
        placeholder: "",
        on_input: EmailContactAddressChanged,
      ),
      admin_ui.text_input(
        label: "Default timeout",
        help: "Fallback timeout in milliseconds when no request deadline is present.",
        value: section.draft.default_timeout_ms,
        placeholder: "",
        on_input: EmailDefaultTimeoutMsChanged,
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
      reset_msg: EmailResetClicked,
      save_msg: EmailSaveClicked,
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

fn load_passkey_config() -> Effect(Msg) {
  api.get_admin_passkey_config(PasskeyLoaded)
}

fn load_cleanup_config() -> Effect(Msg) {
  api.get_admin_cleanup_config(CleanupLoaded)
}

fn load_log_worker_config() -> Effect(Msg) {
  api.get_admin_log_worker_config(LogWorkerLoaded)
}

fn load_language_version_cache_worker_config() -> Effect(Msg) {
  api.get_admin_language_version_cache_worker_config(
    LanguageVersionCacheWorkerLoaded,
  )
}

fn load_docker_run_config() -> Effect(Msg) {
  api.get_admin_docker_run_config(DockerRunLoaded)
}

fn load_cloudflare_config() -> Effect(Msg) {
  api.get_admin_cloudflare_config(CloudflareLoaded)
}

fn load_email_config() -> Effect(Msg) {
  api.get_admin_email_config(EmailLoaded)
}

fn auth_fields_from_response(
  response: auth_config_dto.AuthConfigResponse,
) -> AuthFields {
  AuthFields(
    login_token_max_age: int.to_string(response.login_token_max_age),
    session_token_max_age: int.to_string(response.session_token_max_age),
    session_idle_timeout_seconds: int.to_string(
      response.session_idle_timeout_seconds,
    ),
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

fn passkey_fields_from_response(
  response: passkey_config_dto.PasskeyConfigResponse,
) -> PasskeyFields {
  PasskeyFields(
    origin: response.origin,
    rp_id: response.rp_id,
    challenge_timeout_seconds: int.to_string(response.challenge_timeout_seconds),
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

fn log_worker_fields_from_response(
  response: log_worker_config_dto.LogWorkerConfigResponse,
) -> LogWorkerFields {
  LogWorkerFields(
    flush_interval_ms: int.to_string(response.flush_interval_ms),
    max_batch_size: int.to_string(response.max_batch_size),
    max_buffer_size: int.to_string(response.max_buffer_size),
  )
}

fn language_version_cache_worker_fields_from_response(
  response: language_version_cache_worker_config_dto.LanguageVersionCacheWorkerConfigResponse,
) -> LanguageVersionCacheWorkerFields {
  LanguageVersionCacheWorkerFields(
    refresh_interval_ms: int.to_string(response.refresh_interval_ms),
    refresh_step_delay_ms: int.to_string(response.refresh_step_delay_ms),
    refresh_step_jitter_ms: int.to_string(response.refresh_step_jitter_ms),
    default_timeout_ms: int.to_string(response.default_timeout_ms),
  )
}

fn docker_run_fields_from_response(
  response: docker_run_config_dto.DockerRunConfigResponse,
) -> DockerRunFields {
  DockerRunFields(
    base_url: response.base_url,
    access_token: response.access_token,
    default_timeout_ms: int.to_string(response.default_timeout_ms),
  )
}

fn cloudflare_fields_from_response(
  response: cloudflare_config_dto.CloudflareConfigResponse,
) -> CloudflareFields {
  CloudflareFields(
    account_id: response.account_id,
    api_token: response.api_token,
  )
}

fn email_fields_from_response(
  response: email_config_dto.EmailConfigResponse,
) -> EmailFields {
  EmailFields(
    from_address: response.from_address,
    from_name: option.unwrap(response.from_name, ""),
    contact_address: option.unwrap(response.contact_address, ""),
    default_timeout_ms: int.to_string(response.default_timeout_ms),
  )
}

fn validate_docker_run_fields(
  fields: DockerRunFields,
) -> Result(docker_run_config_dto.UpsertDockerRunConfigRequest, String) {
  use default_timeout_ms <- result.try(
    admin_format.parse_positive_int_with_error(
      fields.default_timeout_ms,
      "Default timeout must be a positive integer.",
    ),
  )

  case fields.base_url, fields.access_token {
    "", _ -> Error("Base URL must not be empty.")
    _, "" -> Error("Access token must not be empty.")
    _, _ ->
      Ok(docker_run_config_dto.UpsertDockerRunConfigRequest(
        base_url: fields.base_url,
        access_token: fields.access_token,
        default_timeout_ms: default_timeout_ms,
      ))
  }
}

fn is_dirty(section: DockerRunSection) -> Bool {
  section.saved != section.draft
}

fn validate_cloudflare_fields(
  fields: CloudflareFields,
) -> Result(cloudflare_config_dto.UpsertCloudflareConfigRequest, String) {
  case fields.account_id, fields.api_token {
    "", _ -> Error("Account ID must not be empty.")
    _, "" -> Error("API token must not be empty.")
    _, _ ->
      Ok(cloudflare_config_dto.UpsertCloudflareConfigRequest(
        account_id: fields.account_id,
        api_token: fields.api_token,
      ))
  }
}

fn is_dirty_cloudflare(section: CloudflareSection) -> Bool {
  section.saved != section.draft
}

fn validate_email_fields(
  fields: EmailFields,
) -> Result(email_config_dto.UpsertEmailConfigRequest, String) {
  use default_timeout_ms <- result.try(
    admin_format.parse_positive_int_with_error(
      fields.default_timeout_ms,
      "Default timeout must be a positive integer.",
    ),
  )

  case fields.from_address {
    "" -> Error("From address must not be empty.")
    _ ->
      Ok(email_config_dto.UpsertEmailConfigRequest(
        from_address: fields.from_address,
        from_name: case fields.from_name {
          "" -> option.None
          value -> option.Some(value)
        },
        contact_address: case fields.contact_address {
          "" -> option.None
          value -> option.Some(value)
        },
        default_timeout_ms: default_timeout_ms,
      ))
  }
}

fn is_dirty_email(section: EmailSection) -> Bool {
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

fn is_dirty_passkey(section: PasskeySection) -> Bool {
  section.saved != section.draft
}

fn is_dirty_cleanup(section: CleanupSection) -> Bool {
  section.saved != section.draft
}

fn is_dirty_log_worker(section: LogWorkerSection) -> Bool {
  section.saved != section.draft
}

fn is_dirty_language_version_cache_worker(
  section: LanguageVersionCacheWorkerSection,
) -> Bool {
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
      "Session max lifetime must be a positive integer.",
    ),
  )
  use session_idle_timeout_seconds <- result.try(
    admin_format.parse_positive_int_with_error(
      fields.session_idle_timeout_seconds,
      "Session idle timeout must be a positive integer.",
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
      "Session rotation interval must be a positive integer.",
    ),
  )
  use session_previous_token_grace_seconds <- result.try(
    admin_format.parse_positive_int_with_error(
      fields.session_previous_token_grace_seconds,
      "Previous token grace window must be a positive integer.",
    ),
  )
  use session_heartbeat_interval_seconds <- result.try(
    admin_format.parse_positive_int_with_error(
      fields.session_heartbeat_interval_seconds,
      "Heartbeat cadence must be a positive integer.",
    ),
  )

  Ok(auth_config_dto.UpsertAuthConfigRequest(
    login_token_max_age: login_token_max_age,
    session_token_max_age: session_token_max_age,
    session_idle_timeout_seconds: session_idle_timeout_seconds,
    session_cookie_max_age: session_cookie_max_age,
    session_refresh_interval_seconds: session_refresh_interval_seconds,
    session_previous_token_grace_seconds: session_previous_token_grace_seconds,
    session_heartbeat_interval_seconds: session_heartbeat_interval_seconds,
  ))
}

fn validate_passkey_fields(
  fields: PasskeyFields,
) -> Result(passkey_config_dto.UpsertPasskeyConfigRequest, String) {
  use challenge_timeout_seconds <- result.try(
    admin_format.parse_positive_int_with_error(
      fields.challenge_timeout_seconds,
      "Challenge timeout must be a positive integer.",
    ),
  )

  case fields.origin, fields.rp_id {
    "", _ -> Error("Origin must not be empty.")
    _, "" -> Error("RP ID must not be empty.")
    _, _ ->
      Ok(passkey_config_dto.UpsertPasskeyConfigRequest(
        origin: fields.origin,
        rp_id: fields.rp_id,
        challenge_timeout_seconds: challenge_timeout_seconds,
      ))
  }
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

fn validate_log_worker_fields(
  fields: LogWorkerFields,
) -> Result(log_worker_config_dto.UpsertLogWorkerConfigRequest, String) {
  use flush_interval_ms <- result.try(
    admin_format.parse_positive_int_with_error(
      fields.flush_interval_ms,
      "Flush interval must be a positive integer.",
    ),
  )
  use max_batch_size <- result.try(admin_format.parse_positive_int_with_error(
    fields.max_batch_size,
    "Max batch size must be a positive integer.",
  ))
  use max_buffer_size <- result.try(admin_format.parse_positive_int_with_error(
    fields.max_buffer_size,
    "Max buffer size must be a positive integer.",
  ))

  case max_buffer_size < max_batch_size {
    True ->
      Error("Max buffer size must be greater than or equal to max batch size.")
    False ->
      Ok(log_worker_config_dto.UpsertLogWorkerConfigRequest(
        flush_interval_ms: flush_interval_ms,
        max_batch_size: max_batch_size,
        max_buffer_size: max_buffer_size,
      ))
  }
}

fn validate_language_version_cache_worker_fields(
  fields: LanguageVersionCacheWorkerFields,
) -> Result(
  language_version_cache_worker_config_dto.UpsertLanguageVersionCacheWorkerConfigRequest,
  String,
) {
  use refresh_interval_ms <- result.try(
    admin_format.parse_positive_int_with_error(
      fields.refresh_interval_ms,
      "Refresh interval must be a positive integer.",
    ),
  )
  use refresh_step_delay_ms <- result.try(
    admin_format.parse_positive_int_with_error(
      fields.refresh_step_delay_ms,
      "Refresh step delay must be a positive integer.",
    ),
  )
  let refresh_step_jitter_ms = case fields.refresh_step_jitter_ms {
    "0" -> Ok(0)
    value ->
      admin_format.parse_positive_int_with_error(
        value,
        "Refresh step jitter must be 0 or a positive integer.",
      )
  }
  use refresh_step_jitter_ms <- result.try(refresh_step_jitter_ms)
  use default_timeout_ms <- result.try(
    admin_format.parse_positive_int_with_error(
      fields.default_timeout_ms,
      "Default timeout must be a positive integer.",
    ),
  )

  Ok(
    language_version_cache_worker_config_dto.UpsertLanguageVersionCacheWorkerConfigRequest(
      refresh_interval_ms: refresh_interval_ms,
      refresh_step_delay_ms: refresh_step_delay_ms,
      refresh_step_jitter_ms: refresh_step_jitter_ms,
      default_timeout_ms: default_timeout_ms,
    ),
  )
}

fn empty_auth_section() -> AuthSection {
  let fields = empty_auth_fields()
  AuthSection(saved: fields, draft: fields, state: mutation.Idle)
}

fn empty_passkey_section() -> PasskeySection {
  let fields = empty_passkey_fields()
  PasskeySection(saved: fields, draft: fields, state: mutation.Idle)
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
    session_idle_timeout_seconds: "",
    session_cookie_max_age: "",
    session_refresh_interval_seconds: "",
    session_previous_token_grace_seconds: "",
    session_heartbeat_interval_seconds: "",
  )
}

fn empty_passkey_fields() -> PasskeyFields {
  PasskeyFields(
    origin: "https://glot.io",
    rp_id: "glot.io",
    challenge_timeout_seconds: "120",
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

fn empty_log_worker_section() -> LogWorkerSection {
  let fields = empty_log_worker_fields()
  LogWorkerSection(saved: fields, draft: fields, state: mutation.Idle)
}

fn empty_log_worker_fields() -> LogWorkerFields {
  LogWorkerFields(
    flush_interval_ms: "",
    max_batch_size: "",
    max_buffer_size: "",
  )
}

fn empty_language_version_cache_worker_section() -> LanguageVersionCacheWorkerSection {
  let fields = empty_language_version_cache_worker_fields()
  LanguageVersionCacheWorkerSection(
    saved: fields,
    draft: fields,
    state: mutation.Idle,
  )
}

fn empty_language_version_cache_worker_fields() -> LanguageVersionCacheWorkerFields {
  LanguageVersionCacheWorkerFields(
    refresh_interval_ms: "",
    refresh_step_delay_ms: "",
    refresh_step_jitter_ms: "",
    default_timeout_ms: "",
  )
}

fn empty_docker_run_section() -> DockerRunSection {
  let fields = empty_docker_run_fields()
  DockerRunSection(saved: fields, draft: fields, state: mutation.Idle)
}

fn empty_docker_run_fields() -> DockerRunFields {
  DockerRunFields(base_url: "", access_token: "", default_timeout_ms: "")
}

fn empty_cloudflare_section() -> CloudflareSection {
  let fields = empty_cloudflare_fields()
  CloudflareSection(saved: fields, draft: fields, state: mutation.Idle)
}

fn empty_cloudflare_fields() -> CloudflareFields {
  CloudflareFields(account_id: "", api_token: "")
}

fn empty_email_section() -> EmailSection {
  let fields = empty_email_fields()
  EmailSection(saved: fields, draft: fields, state: mutation.Idle)
}

fn empty_email_fields() -> EmailFields {
  EmailFields(
    from_address: "",
    from_name: "",
    contact_address: "",
    default_timeout_ms: "",
  )
}

fn loaded_status(model: Model) -> Status {
  case
    model.debug_loaded
    && model.availability_loaded
    && model.auth_loaded
    && model.passkey_loaded
    && model.cleanup_loaded
    && model.log_worker_loaded
    && model.language_version_cache_worker_loaded
    && model.docker_run_loaded
    && model.cloudflare_loaded
    && model.email_loaded
  {
    True -> Ready
    False -> Loading
  }
}
