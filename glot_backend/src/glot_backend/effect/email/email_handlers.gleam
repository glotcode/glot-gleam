import gleam/dict
import gleam/json
import gleam/string
import glot_backend/cloudflare_email
import glot_backend/dynamic_config
import glot_backend/effect/error
import glot_backend/effect/error/infra_error
import glot_backend/http_client
import glot_core/email/email_model
import wisp

pub type EmailHandlers {
  EmailHandlers(
    send_email: fn(dynamic_config.CloudflareConfig, email_model.Email, Int) ->
      Result(email_model.SendEmailResult, error.Error),
  )
}

pub fn new() -> EmailHandlers {
  EmailHandlers(send_email: send_email)
}

pub fn send_email(
  cfg: dynamic_config.CloudflareConfig,
  message: email_model.Email,
  timeout_ms: Int,
) -> Result(email_model.SendEmailResult, error.Error) {
  let request = cloudflare_email.request_from_email(message)
  let response_result =
    http_client.post_json(
      url: "https://api.cloudflare.com/client/v4/accounts/"
        <> cfg.account_id
        <> "/email/sending/send",
      body: cloudflare_email.encode_request(request),
      headers: dict.from_list([#("authorization", "Bearer " <> cfg.api_token)]),
      timeout_ms: timeout_ms,
      decoder: cloudflare_email.response_decoder(),
    )

  case response_result {
    Ok(response) ->
      case response.success {
        True -> Ok(send_result_from_cloudflare(response.result))
        False -> {
          let detail = cloudflare_email.response_message(response)
          wisp.log_error("Cloudflare email send failed: " <> detail)
          Error(
            error.infra(
              infra_error.EmailError(infra_error.EmailDeliveryFailed(
                "cloudflare:" <> detail,
              )),
            ),
          )
        }
      }
    Error(err) -> {
      wisp.log_error("Cloudflare email request failed: " <> string.inspect(err))
      Error(error_from_http_error(err))
    }
  }
}

fn send_result_from_cloudflare(
  result: cloudflare_email.SendEmailResult,
) -> email_model.SendEmailResult {
  let cloudflare_email.SendEmailResult(
    delivered: delivered,
    permanent_bounces: permanent_bounces,
    queued: queued,
  ) = result

  email_model.SendEmailResult(
    delivered: delivered,
    permanent_bounces: permanent_bounces,
    queued: queued,
  )
}

fn error_from_http_error(err: http_client.HttpError) -> error.Error {
  case err {
    http_client.BadStatus(status: _, body: body) ->
      case json.parse(body, cloudflare_email.response_decoder()) {
        Ok(response) -> {
          let detail = cloudflare_email.response_message(response)
          wisp.log_error("Cloudflare email bad status: " <> detail)
          error.infra(
            infra_error.EmailError(infra_error.EmailDeliveryFailed(
              "cloudflare:" <> detail,
            )),
          )
        }
        Error(_) ->
          error.infra(
            infra_error.EmailError(infra_error.EmailDeliveryFailed(
              "http_bad_status:" <> string.inspect(err),
            )),
          )
      }
    http_client.Timeout ->
      error.infra(
        infra_error.EmailError(infra_error.EmailDeliveryFailed("http_timeout")),
      )
    http_client.NetworkError ->
      error.infra(
        infra_error.EmailError(infra_error.EmailDeliveryFailed(
          "http_network_error",
        )),
      )
    http_client.BadUrl(url) ->
      error.infra(
        infra_error.EmailError(infra_error.EmailDeliveryFailed(
          "bad_url:" <> url,
        )),
      )
    http_client.BadBody(message) ->
      error.infra(
        infra_error.EmailError(infra_error.EmailDeliveryFailed(
          "bad_response_body:" <> message,
        )),
      )
  }
}
