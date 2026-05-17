import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/string
import glot_core/email/email_address_model
import glot_core/email/email_model

pub type SendEmailRequest {
  SendEmailRequest(
    from: email_model.EmailSender,
    subject: String,
    to: List(email_address_model.EmailAddress),
    text: String,
    html: option.Option(String),
  )
}

pub type CloudflareMessage {
  CloudflareMessage(code: Int, message: String)
}

pub type SendEmailResult {
  SendEmailResult(
    delivered: List(String),
    permanent_bounces: List(String),
    queued: List(String),
  )
}

pub type SendEmailResponse {
  SendEmailResponse(
    success: Bool,
    errors: List(CloudflareMessage),
    messages: List(CloudflareMessage),
    result: SendEmailResult,
  )
}

pub fn request_from_email(email: email_model.Email) -> SendEmailRequest {
  SendEmailRequest(
    from: email.from,
    subject: email.subject,
    to: [email.to],
    text: email.text_body,
    html: email.html_body,
  )
}

pub fn encode_request(request: SendEmailRequest) -> json.Json {
  let base_fields = [
    #("from", encode_sender(request.from)),
    #("subject", json.string(request.subject)),
    #("to", json.array(request.to, email_address_model.encode)),
    #("text", json.string(request.text)),
  ]

  let fields = case request.html {
    option.Some(html) ->
      list.append(base_fields, [#("html", json.string(html))])
    option.None -> base_fields
  }

  json.object(fields)
}

pub fn response_decoder() -> decode.Decoder(SendEmailResponse) {
  use success <- decode.field("success", decode.bool)
  use errors <- decode.field("errors", decode.list(message_decoder()))
  use messages <- decode.field("messages", decode.list(message_decoder()))
  use result <- decode.field("result", result_decoder())
  decode.success(SendEmailResponse(success:, errors:, messages:, result:))
}

pub fn response_message(response: SendEmailResponse) -> String {
  case response.errors {
    [] ->
      case response.messages {
        [] -> "Cloudflare email request failed"
        messages -> join_messages(messages)
      }
    errors -> join_messages(errors)
  }
}

fn message_decoder() -> decode.Decoder(CloudflareMessage) {
  use code <- decode.field("code", decode.int)
  use message <- decode.field("message", decode.string)
  decode.success(CloudflareMessage(code:, message:))
}

fn result_decoder() -> decode.Decoder(SendEmailResult) {
  use delivered <- decode.field("delivered", decode.list(decode.string))
  use permanent_bounces <- decode.field(
    "permanent_bounces",
    decode.list(decode.string),
  )
  use queued <- decode.field("queued", decode.list(decode.string))
  decode.success(SendEmailResult(delivered:, permanent_bounces:, queued:))
}

fn join_messages(messages: List(CloudflareMessage)) -> String {
  messages
  |> list.map(fn(message) {
    let CloudflareMessage(code: code, message: text) = message
    "[" <> int.to_string(code) <> "] " <> text
  })
  |> string.join(with: "; ")
}

fn encode_sender(sender: email_model.EmailSender) -> json.Json {
  case sender.name {
    option.Some(name) ->
      json.object([
        #("address", email_address_model.encode(sender.address)),
        #("name", json.string(name)),
      ])
    option.None -> email_address_model.encode(sender.address)
  }
}
