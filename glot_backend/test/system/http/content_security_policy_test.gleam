import gleam/http/response as http_response
import glot_backend/system/http/content_security_policy
import wisp

pub fn policy_serializes_reviewed_directives_test() {
  assert content_security_policy.policy()
    == "default-src 'self'; base-uri 'self'; connect-src 'self'; font-src 'self'; form-action 'self'; frame-ancestors 'none'; img-src 'self' data:; object-src 'none'; script-src 'self' https://cdn.carbonads.com https://srv.carbonads.net; style-src 'self'"
}

pub fn report_only_mode_uses_report_only_header_test() {
  let response =
    wisp.response(200)
    |> content_security_policy.add(content_security_policy.ReportOnly)

  assert http_response.get_header(
      response,
      "content-security-policy-report-only",
    )
    == Ok(content_security_policy.policy())
  assert http_response.get_header(response, "content-security-policy")
    == Error(Nil)
}

pub fn enforce_mode_uses_enforcing_header_test() {
  let response =
    wisp.response(200)
    |> content_security_policy.add(content_security_policy.Enforce)

  assert http_response.get_header(response, "content-security-policy")
    == Ok(content_security_policy.policy())
  assert http_response.get_header(
      response,
      "content-security-policy-report-only",
    )
    == Error(Nil)
}
