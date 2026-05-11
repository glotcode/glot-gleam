import gleam/dynamic/decode
import gleam/json
import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_core/helpers/timestamp_helpers

pub type EmailTemplateSummaryResponse {
  EmailTemplateSummaryResponse(
    name: String,
    subject_template: String,
    supported_tokens: List(String),
    has_html_body: Bool,
    updated_at: Timestamp,
  )
}

pub type EmailTemplateDetailResponse {
  EmailTemplateDetailResponse(
    name: String,
    subject_template: String,
    text_body_template: String,
    html_body_template: option.Option(String),
    supported_tokens: List(String),
    updated_at: Timestamp,
  )
}

pub type ListEmailTemplatesResponse {
  ListEmailTemplatesResponse(templates: List(EmailTemplateSummaryResponse))
}

pub type GetEmailTemplateRequest {
  GetEmailTemplateRequest(name: String)
}

pub type GetEmailTemplateResponse {
  GetEmailTemplateResponse(template: EmailTemplateDetailResponse)
}

pub type UpdateEmailTemplateRequest {
  UpdateEmailTemplateRequest(
    name: String,
    subject_template: String,
    text_body_template: String,
    html_body_template: option.Option(String),
  )
}

pub type UpdateEmailTemplateResponse {
  UpdateEmailTemplateResponse(template: EmailTemplateDetailResponse)
}

pub fn list_response_decoder() -> decode.Decoder(ListEmailTemplatesResponse) {
  use templates <- decode.field("templates", decode.list(summary_decoder()))
  decode.success(ListEmailTemplatesResponse(templates: templates))
}

pub fn encode_list_response(response: ListEmailTemplatesResponse) -> json.Json {
  json.object([
    #("templates", json.array(response.templates, encode_summary)),
  ])
}

pub fn get_request_decoder() -> decode.Decoder(GetEmailTemplateRequest) {
  use name <- decode.field("name", decode.string)
  decode.success(GetEmailTemplateRequest(name: name))
}

pub fn encode_get_request(request: GetEmailTemplateRequest) -> json.Json {
  json.object([#("name", json.string(request.name))])
}

pub fn get_response_decoder() -> decode.Decoder(GetEmailTemplateResponse) {
  use template <- decode.field("template", detail_decoder())
  decode.success(GetEmailTemplateResponse(template: template))
}

pub fn encode_get_response(response: GetEmailTemplateResponse) -> json.Json {
  json.object([#("template", encode_detail(response.template))])
}

pub fn update_request_decoder() -> decode.Decoder(UpdateEmailTemplateRequest) {
  use name <- decode.field("name", decode.string)
  use subject_template <- decode.field("subjectTemplate", decode.string)
  use text_body_template <- decode.field("textBodyTemplate", decode.string)
  use html_body_template <- decode.field(
    "htmlBodyTemplate",
    decode.optional(decode.string),
  )
  decode.success(UpdateEmailTemplateRequest(
    name: name,
    subject_template: subject_template,
    text_body_template: text_body_template,
    html_body_template: html_body_template,
  ))
}

pub fn encode_update_request(request: UpdateEmailTemplateRequest) -> json.Json {
  json.object([
    #("name", json.string(request.name)),
    #("subjectTemplate", json.string(request.subject_template)),
    #("textBodyTemplate", json.string(request.text_body_template)),
    #(
      "htmlBodyTemplate",
      json.nullable(request.html_body_template, json.string),
    ),
  ])
}

pub fn update_response_decoder() -> decode.Decoder(UpdateEmailTemplateResponse) {
  use template <- decode.field("template", detail_decoder())
  decode.success(UpdateEmailTemplateResponse(template: template))
}

pub fn encode_update_response(
  response: UpdateEmailTemplateResponse,
) -> json.Json {
  json.object([#("template", encode_detail(response.template))])
}

fn summary_decoder() -> decode.Decoder(EmailTemplateSummaryResponse) {
  use name <- decode.field("name", decode.string)
  use subject_template <- decode.field("subjectTemplate", decode.string)
  use supported_tokens <- decode.field(
    "supportedTokens",
    decode.list(decode.string),
  )
  use has_html_body <- decode.field("hasHtmlBody", decode.bool)
  use updated_at <- decode.field("updatedAt", timestamp_helpers.decoder())
  decode.success(EmailTemplateSummaryResponse(
    name: name,
    subject_template: subject_template,
    supported_tokens: supported_tokens,
    has_html_body: has_html_body,
    updated_at: updated_at,
  ))
}

fn encode_summary(response: EmailTemplateSummaryResponse) -> json.Json {
  json.object([
    #("name", json.string(response.name)),
    #("subjectTemplate", json.string(response.subject_template)),
    #("supportedTokens", json.array(response.supported_tokens, json.string)),
    #("hasHtmlBody", json.bool(response.has_html_body)),
    #("updatedAt", timestamp_helpers.encode(response.updated_at)),
  ])
}

fn detail_decoder() -> decode.Decoder(EmailTemplateDetailResponse) {
  use name <- decode.field("name", decode.string)
  use subject_template <- decode.field("subjectTemplate", decode.string)
  use text_body_template <- decode.field("textBodyTemplate", decode.string)
  use html_body_template <- decode.field(
    "htmlBodyTemplate",
    decode.optional(decode.string),
  )
  use supported_tokens <- decode.field(
    "supportedTokens",
    decode.list(decode.string),
  )
  use updated_at <- decode.field("updatedAt", timestamp_helpers.decoder())
  decode.success(EmailTemplateDetailResponse(
    name: name,
    subject_template: subject_template,
    text_body_template: text_body_template,
    html_body_template: html_body_template,
    supported_tokens: supported_tokens,
    updated_at: updated_at,
  ))
}

fn encode_detail(response: EmailTemplateDetailResponse) -> json.Json {
  json.object([
    #("name", json.string(response.name)),
    #("subjectTemplate", json.string(response.subject_template)),
    #("textBodyTemplate", json.string(response.text_body_template)),
    #(
      "htmlBodyTemplate",
      json.nullable(response.html_body_template, json.string),
    ),
    #("supportedTokens", json.array(response.supported_tokens, json.string)),
    #("updatedAt", timestamp_helpers.encode(response.updated_at)),
  ])
}
