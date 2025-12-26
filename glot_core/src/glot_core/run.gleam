import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option}
import glot_core/language
import glot_core/snippet

pub type RunRequest {
  RunRequest(image: String, payload: RunRequestPayload)
}

pub type RunRequestPayload {
  RunRequestPayload(
    run_instructions: language.RunInstructions,
    files: List(snippet.File),
    stdin: Option(String),
  )
}

pub type SuccessfulRun {
  SuccessfulRun(duration: Int, stdout: String, stderr: String, error: String)
}

pub type FailedRun {
  FailedRun(message: String)
}

pub type RunResult =
  Result(SuccessfulRun, FailedRun)

pub fn is_empty(r: SuccessfulRun) -> Bool {
  r.stdout == "" && r.stderr == "" && r.error == ""
}

pub fn encode_run_request(req: RunRequest) -> json.Json {
  json.object([
    #("image", json.string(req.image)),
    #("payload", encode_run_request_payload(req.payload)),
  ])
}

pub fn encode_run_request_payload(payload: RunRequestPayload) -> json.Json {
  json.object([
    #(
      "runInstructions",
      language.encode_run_instructions(payload.run_instructions),
    ),
    #("files", json.array(payload.files, snippet.encode_file)),
    #("stdin", case payload.stdin {
      option.Some(s) -> json.string(s)
      option.None -> json.null()
    }),
  ])
}

pub fn run_request_decoder() -> decode.Decoder(RunRequest) {
  use image <- decode.field("image", decode.string)
  use payload <- decode.field("payload", run_request_payload_decoder())
  decode.success(RunRequest(image:, payload:))
}

pub fn run_request_payload_decoder() -> decode.Decoder(RunRequestPayload) {
  use run_instructions <- decode.field(
    "runInstructions",
    language.run_instructions_decoder(),
  )
  use files <- decode.field("files", decode.list(snippet.file_decoder()))
  use stdin <- decode.field("stdin", decode.optional(decode.string))

  decode.success(RunRequestPayload(
    run_instructions: run_instructions,
    files: files,
    stdin: stdin,
  ))
}

pub fn successful_run_decoder() -> decode.Decoder(SuccessfulRun) {
  use duration <- decode.field("duration", decode.int)
  use stdout <- decode.field("stdout", decode.string)
  use stderr <- decode.field("stderr", decode.string)
  use error <- decode.field("error", decode.string)
  decode.success(SuccessfulRun(duration:, stdout:, stderr:, error:))
}

pub fn failed_run_decoder() -> decode.Decoder(FailedRun) {
  use message <- decode.field("message", decode.string)
  decode.success(FailedRun(message:))
}

pub fn run_result_decoder() -> decode.Decoder(RunResult) {
  decode.one_of(decode.map(successful_run_decoder(), Ok), or: [
    decode.map(failed_run_decoder(), Error),
  ])
}

pub fn encode_run_result(result: RunResult) -> json.Json {
  case result {
    Ok(success) ->
      json.object([
        #("duration", json.int(success.duration)),
        #("stdout", json.string(success.stdout)),
        #("stderr", json.string(success.stderr)),
        #("error", json.string(success.error)),
      ])
    Error(failure) ->
      json.object([
        #("message", json.string(failure.message)),
      ])
  }
}
