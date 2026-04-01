import glot_backend/context
import glot_backend/effect/auth/auth_handlers
import glot_backend/effect/core/core_handlers
import glot_backend/effect/docker_run/docker_run_handlers
import glot_backend/effect
import glot_backend/effect/runtime_types
import glot_backend/effect/transaction/transaction_handlers

pub fn from_context(ctx: context.Context) -> effect.Handlers {
  runtime_types.Handlers(
    new_token: core_handlers.new_token,
    system_time: core_handlers.system_time,
    uuid_v7: fn() { core_handlers.uuid_v7(ctx) },
    post_run_request: docker_run_handlers.post_run_request,
    send_email: core_handlers.send_email,
    get_user_by_email: fn(email) { auth_handlers.get_user_by_email(ctx, email) },
    list_login_tokens_by_user: fn(user_id, limit) {
      auth_handlers.list_login_tokens_by_user(ctx, user_id, limit)
    },
    get_session_by_token: fn(token) { auth_handlers.get_session_by_token(ctx, token) },
    get_next_job: fn(now, pending_status, running_status) {
      core_handlers.get_next_job(ctx, now, pending_status, running_status)
    },
    count_user_actions_by_ip: fn(windows, ip, action) {
      core_handlers.count_user_actions_by_ip(ctx, ip, action, windows)
    },
    count_user_actions_by_user: fn(windows, user_id, action) {
      core_handlers.count_user_actions_by_user(ctx, user_id, action, windows)
    },
    run_command: fn(command) { transaction_handlers.run_command(ctx.db, command) },
    run_in_transaction: fn(commands) {
      transaction_handlers.run_in_transaction(ctx.db, commands)
    },
  )
}
