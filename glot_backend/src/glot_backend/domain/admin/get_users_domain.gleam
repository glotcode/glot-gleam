import gleam/dynamic
import gleam/option
import gleam/result
import glot_backend/context
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/effect/auth/auth_algebra
import glot_backend/effect/auth/auth_effect
import glot_backend/effect/error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_core/admin/user_dto
import glot_core/admin_action
import glot_core/api_action
import glot_core/pagination_model
import youid/uuid

pub fn get_users(
  ctx: context.Context,
  request: user_dto.ListUsersRequest,
) -> program_types.Program(user_dto.ListUsersResponse) {
  let pagination = request.pagination
  use _ <- program.and_then(
    pagination_model.validate(pagination, 100)
    |> result.map_error(error.validation)
    |> program.from_result,
  )
  use session <- program.and_then(session_domain.require_session(ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.admin(admin_action.GetAdminUsersAction),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use users <- program.and_then(auth_effect.list_users(
    pagination_model.increment_limit(pagination),
    auth_algebra.UserListFilters(
      email: request.email,
      username: request.username,
      id: request.id,
      role: request.role,
      account_state: request.account_state,
      account_tier: request.account_tier,
    ),
  ))

  let page =
    pagination_model.paginate(users, pagination, fn(user) {
      pagination_model.from_string(uuid.to_string(user.identity.id))
    })

  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(user_dto.from_users(page))
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(user_dto.ListUsersRequest) {
  program.decode_dynamic(data, user_dto.list_request_decoder())
}
