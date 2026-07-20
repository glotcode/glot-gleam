import glot_backend/api/handler as api
import glot_backend/auth/error as auth_error
import glot_backend/system/effect/error
import glot_backend/system/effect/error/resource_error
import glot_backend/system/effect/error/run_request_error
import glot_core/rate_limit
import glot_core/validation_error

pub fn api_error_status_mapping_test() {
  assert api.error_status(error.validation(validation_error.InvalidLimit))
    == 400
  assert api.error_status(error.resource(resource_error.SnippetNotFound)) == 404
  assert api.error_status(error.resource(
      resource_error.AccountDeleteNotScheduled,
    ))
    == 409
  assert api.error_status(error.auth(auth_error.MissingSessionToken)) == 401
  assert api.error_status(error.auth(auth_error.NotOwner)) == 403
  assert api.error_status(error.too_many_requests(
      3,
      rate_limit.RateLimit(unit: rate_limit.Minute, max_requests: 2),
    ))
    == 429
  assert api.error_status(error.run_request_error(
      run_request_error.ServerRunRequestError,
    ))
    == 500
}

pub fn api_error_detail_codes_test() {
  assert api.api_error_details(error.auth(auth_error.InvalidLoginToken))
    == #(401, "login_invalid_token", "Invalid login token")
  assert api.api_error_details(error.auth(auth_error.LoginTokenUsed))
    == #(409, "login_token_used", "Login token already used")
  assert api.api_error_details(error.auth(auth_error.SessionExpired))
    == #(401, "session_expired", "Session expired")
  assert api.api_error_details(error.auth(auth_error.NotOwner))
    == #(403, "authorization_not_owner", "Not authorized")
  assert api.api_error_details(error.validation(validation_error.FilesMissing))
    == #(
      400,
      "validation_files_missing",
      "files must contain at least one file",
    )
  assert api.api_error_details(
      error.validation(validation_error.FieldTooLong("title", 200)),
    )
    == #(
      400,
      "validation_title_too_long",
      "title must be at most 200 characters",
    )
  assert api.api_error_details(
      error.validation(validation_error.FieldTooLong(
        "files[0].content",
        100_000,
      )),
    )
    == #(
      400,
      "validation_files_0_content_too_long",
      "files[0].content must be at most 100000 characters",
    )
}
