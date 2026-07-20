import glot_backend/run_code/domain/get_language_version as get_language_version_domain
import glot_backend/system/effect/error
import glot_backend/system/effect/error/run_request_error
import glot_backend/system/request/hydrated_context as request_context
import glot_core/language
import glot_core/run
import support/integration/fixture
import support/integration/profile/run_code as runner

pub fn get_language_version_without_session_reaches_docker_run_test() {
  let ctx = fixture.test_context()
  let request = run.GetLanguageVersionRequest(language: language.Python)

  let #(run_result, db) =
    runner.run_test_program(
      get_language_version_domain.get_language_version(
        request_context.new(ctx, fixture.test_dynamic_config()),
        request,
      ),
      ctx,
      fixture.empty_test_state(),
    )

  assert run_result
    == Error(error.run_request_error(run_request_error.ServerRunRequestError))
  assert db.write_steps == []
}
