import gleam/dynamic/decode
import gleam/http/response as http_response
import gleeunit
import glot_frontend/api/client
import glot_frontend/api/response
import youid/uuid

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn decodes_success_payload_test() {
  let received =
    http_response.new(200)
    |> http_response.set_header(
      "content-type",
      "application/json; charset=utf-8",
    )
    |> http_response.set_body("{\"data\":\"ok\"}")

  assert client.decode_response(received, decode.string)
    == Ok(response.Success("ok"))
}

pub fn decodes_structured_api_failure_test() {
  let request_id = uuid.v7()
  let body =
    "{\"error\":{\"code\":\"invalid_request\",\"message\":\"Invalid\",\"requestId\":\""
    <> uuid.to_string(request_id)
    <> "\"}}"
  let received =
    http_response.new(400)
    |> http_response.set_header("content-type", "application/json")
    |> http_response.set_body(body)

  assert client.decode_response(received, decode.string)
    == Ok(
      response.ApiFailure(response.Error(
        code: "invalid_request",
        message: "Invalid",
        request_id:,
      )),
    )
}

pub fn rejects_non_json_responses_test() {
  let received = http_response.new(200) |> http_response.set_body("ok")

  let assert Error(_) = client.decode_response(received, decode.string)
}
