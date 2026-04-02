import glot_backend/context
import glot_backend/effect/auth/auth_handlers
import glot_backend/effect/auth/auth_handlers_type
import glot_backend/effect/core/core_handlers
import glot_backend/effect/core/core_handlers_type
import glot_backend/effect/docker_run/docker_run_handlers
import glot_backend/effect/docker_run/docker_run_handlers_type
import glot_backend/effect/error
import glot_backend/effect/effect_model
import glot_backend/effect/handlers_types
import glot_backend/effect/job/job_handlers
import glot_backend/effect/job/job_handlers_type
import glot_backend/effect/program_state
import glot_backend/effect/snippet/snippet_handlers
import glot_backend/effect/snippet/snippet_handlers_type
import glot_backend/effect/transaction/transaction_handlers_type

pub fn from_context(
  ctx: context.Context,
  run_in_transaction: fn(List(effect_model.Program(Nil))) ->
    #(Result(Nil, error.DbTransactionError), program_state.State),
) -> handlers_types.Handlers {
  handlers_types.Handlers(
    core: core_handlers_type.CoreHandlers(
      new_token: core_handlers.new_token,
      system_time: core_handlers.system_time,
      uuid_v7: fn() { core_handlers.uuid_v7(ctx) },
      send_email: core_handlers.send_email,
      count_user_actions_by_ip: fn(windows, ip, action) {
        core_handlers.count_user_actions_by_ip(ctx, ip, action, windows)
      },
      count_user_actions_by_user: fn(windows, user_id, action) {
        core_handlers.count_user_actions_by_user(ctx, user_id, action, windows)
      },
      insert_user_action: fn(id, request_id, action, ip, user_id, created_at) {
        core_handlers.insert_user_action(
          ctx.db,
          id,
          request_id,
          action,
          ip,
          user_id,
          created_at,
        )
      },
    ),
    job: job_handlers_type.JobHandlers(
      get_next_job: fn(now, pending_status, running_status) {
        job_handlers.get_next_job(ctx, now, pending_status, running_status)
      },
      insert_job: fn(job) { job_handlers.insert_job(ctx.db, job) },
      mark_job_done: fn(id, completed_at) {
        job_handlers.mark_job_done(ctx.db, id, completed_at)
      },
      reschedule_job: fn(id, run_at, last_error, updated_at) {
        job_handlers.reschedule_job(ctx.db, id, run_at, last_error, updated_at)
      },
    ),
    auth: auth_handlers_type.AuthHandlers(
      get_user_by_email: fn(email) { auth_handlers.get_user_by_email(ctx, email) },
      list_login_tokens_by_user: fn(user_id, limit) {
        auth_handlers.list_login_tokens_by_user(ctx, user_id, limit)
      },
      get_session_by_token: fn(token) {
        auth_handlers.get_session_by_token(ctx, token)
      },
      insert_user: fn(id, email, created_at) {
        auth_handlers.insert_user(ctx.db, id, email, created_at)
      },
      insert_session: fn(id, user_id, token, ip, user_agent, created_at) {
        auth_handlers.insert_session(
          ctx.db,
          id,
          user_id,
          token,
          ip,
          user_agent,
          created_at,
        )
      },
      insert_login_token: fn(id, user_id, token, created_at, used_at) {
        auth_handlers.insert_login_token(
          ctx.db,
          id,
          user_id,
          token,
          created_at,
          used_at,
        )
      },
      update_login_token: fn(user_id, token, created_at, used_at, id) {
        auth_handlers.update_login_token(
          ctx.db,
          user_id,
          token,
          created_at,
          used_at,
          id,
        )
      },
    ),
    snippet: snippet_handlers_type.SnippetHandlers(
      insert_snippet: fn(id, user_id, snippet, created_at, updated_at) {
        snippet_handlers.insert_snippet(
          ctx.db,
          id,
          user_id,
          snippet,
          created_at,
          updated_at,
        )
      },
    ),
    docker_run: docker_run_handlers_type.DockerRunHandlers(
      post_run_request: docker_run_handlers.post_run_request,
    ),
    transaction: transaction_handlers_type.TransactionHandlers(
      run_in_transaction: run_in_transaction,
    ),
  )
}
