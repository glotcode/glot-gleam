import gleam/option
import gleam/time/timestamp
import glot_core/admin/periodic_job_dto
import glot_frontend/admin/command
import glot_frontend/admin/effect/jobs
import glot_frontend/admin/local_datetime
import glot_frontend/admin/periodic_jobs/editor_policy as periodic_job_policy
import glot_frontend/admin/periodic_jobs/managed as periodic_job_managed
import glot_frontend/admin/periodic_jobs/message as periodic_job_message
import glot_frontend/admin/periodic_jobs/model as periodic_job_model
import glot_frontend/api/response
import youid/uuid

pub fn periodic_job_mutation_covers_reset_failure_retry_and_success_test() {
  let fixture = periodic_job_fixture(60)
  let #(base, _) = periodic_job_managed.init(fixture.id)
  let editor =
    periodic_job_policy.from_response(
      fixture,
      local_datetime.LocalDateTime("2026-07-22", "12:30"),
    )
  let initial =
    periodic_job_model.Model(
      ..base,
      periodic_job: option.Some(editor),
      status: periodic_job_model.Ready,
    )
  let #(edited, _) =
    periodic_job_managed.update(
      initial,
      periodic_job_message.IntervalSecondsChanged("120"),
    )
  let #(reset, _) =
    periodic_job_managed.update(edited, periodic_job_message.ResetClicked)
  let assert option.Some(reset_editor) = reset.periodic_job
  assert reset_editor.draft == reset_editor.saved

  let #(edited, _) =
    periodic_job_managed.update(
      reset,
      periodic_job_message.IntervalSecondsChanged("120"),
    )
  let #(parsing, parse_command) =
    periodic_job_managed.update(edited, periodic_job_message.SaveClicked)
  let assert command.ParseLocalDateTime(_, _, parsed) = parse_command
  let now = timestamp.from_unix_seconds(100)
  let #(saving, save_command) =
    periodic_job_managed.update(parsing, parsed(option.Some(now)))
  let assert command.Jobs(jobs.UpdatePeriodicJob(request, complete)) =
    save_command
  assert request.interval_seconds == 120

  let #(failed, _) =
    periodic_job_managed.update(
      saving,
      complete(api_failure("Periodic job rejected.")),
    )
  let assert option.Some(failed_editor) = failed.periodic_job
  let assert periodic_job_model.SaveError(_) = failed_editor.state

  let #(retry_parsing, retry_parse_command) =
    periodic_job_managed.update(failed, periodic_job_message.SaveClicked)
  let assert command.ParseLocalDateTime(_, _, retry_parsed) =
    retry_parse_command
  let #(retrying, retry_command) =
    periodic_job_managed.update(retry_parsing, retry_parsed(option.Some(now)))
  let assert command.Jobs(jobs.UpdatePeriodicJob(_, retry)) = retry_command
  let saved_fixture = periodic_job_fixture(120)
  let #(formatting, format_command) =
    periodic_job_managed.update(
      retrying,
      retry(
        response.Success(periodic_job_dto.UpdatePeriodicJobResponse(
          saved_fixture,
        )),
      ),
    )
  let assert command.FormatLocalDateTime(_, formatted) = format_command
  let #(saved, _) =
    periodic_job_managed.update(
      formatting,
      formatted(local_datetime.LocalDateTime("2026-07-22", "12:30")),
    )
  let assert option.Some(saved_editor) = saved.periodic_job
  assert saved_editor.state == periodic_job_model.Idle
  assert saved_editor.draft == saved_editor.saved
  assert saved_editor.saved.interval_seconds == "120"
}

fn periodic_job_fixture(
  interval_seconds: Int,
) -> periodic_job_dto.PeriodicJobResponse {
  let now = timestamp.from_unix_seconds(100)
  periodic_job_dto.PeriodicJobResponse(
    id: periodic_job_id(),
    job_type: "fixture",
    payload: option.None,
    interval_seconds: interval_seconds,
    enabled: True,
    next_run_at: now,
    last_enqueued_at: option.None,
    last_enqueue_error: option.None,
    created_at: now,
    updated_at: now,
  )
}

fn periodic_job_id() -> uuid.Uuid {
  let assert Ok(id) = uuid.from_string("00000000-0000-4000-8000-000000000093")
  id
}

fn api_failure(message: String) -> response.Response(value) {
  let assert Ok(id) = uuid.from_string("00000000-0000-4000-8000-000000000099")
  response.ApiFailure(response.Error("fixture", message, id))
}
