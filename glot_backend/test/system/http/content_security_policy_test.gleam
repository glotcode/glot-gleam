import gleam/http/response as http_response
import glot_backend/system/http/content_security_policy
import wisp

pub fn application_policy_serializes_reviewed_directives_test() {
  assert content_security_policy.policy(content_security_policy.Application)
    == "default-src 'self'; base-uri 'self'; connect-src 'self'; font-src 'self'; form-action 'self'; frame-ancestors 'none'; frame-src 'self'; img-src 'self' data:; object-src 'none'; script-src 'self'; style-src 'self'"
}

pub fn carbon_ad_policy_serializes_reviewed_directives_test() {
  assert content_security_policy.policy(content_security_policy.CarbonAd)
    == "default-src 'none'; base-uri 'none'; connect-src https://srv.carbonads.net; form-action 'none'; frame-ancestors 'self'; img-src data: https:; object-src 'none'; script-src https://cdn.carbonads.com https://cdn4.buysellads.net; style-src 'unsafe-inline'"
}

pub fn report_only_mode_uses_report_only_header_test() {
  let response =
    wisp.response(200)
    |> content_security_policy.add(
      content_security_policy.ReportOnly,
      content_security_policy.Application,
    )

  assert http_response.get_header(
      response,
      "content-security-policy-report-only",
    )
    == Ok(content_security_policy.policy(content_security_policy.Application))
  assert http_response.get_header(response, "content-security-policy")
    == Error(Nil)
}

pub fn enforce_mode_uses_enforcing_header_test() {
  let response =
    wisp.response(200)
    |> content_security_policy.add(
      content_security_policy.Enforce,
      content_security_policy.Application,
    )

  assert http_response.get_header(response, "content-security-policy")
    == Ok(content_security_policy.policy(content_security_policy.Application))
  assert http_response.get_header(
      response,
      "content-security-policy-report-only",
    )
    == Error(Nil)
}
