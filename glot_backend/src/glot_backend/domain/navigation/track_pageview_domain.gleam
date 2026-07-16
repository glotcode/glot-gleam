import gleam/dynamic
import gleam/option
import glot_backend/domain/shared/session_domain
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/log
import glot_backend/request_context
import glot_core/pageview_dto
import youid/uuid.{type Uuid}

pub type TrackedPageview {
  TrackedPageview(
    id: Uuid,
    session_id: option.Option(Uuid),
    user_id: option.Option(Uuid),
    route: String,
    path: String,
  )
}

pub fn track_pageview(
  request_ctx: request_context.RequestContext,
  request: pageview_dto.PageviewRequest,
) -> program_types.Program(TrackedPageview) {
  use maybe_session <- program.and_then(session_domain.get_session(request_ctx))
  let maybe_session_id =
    option.map(maybe_session, fn(session) { session.identity.id })
  let maybe_user_id =
    option.map(maybe_session, fn(session) { session.user.identity.id })

  use _ <- program.and_then(
    basic_effect.info(
      log.from_list([
        log.uuid("pageview_id", request.id),
        log.string("route", request.route),
        log.string("path", request.path),
        log.optional_uuid("session_id", maybe_session_id),
        log.optional_uuid("user_id", maybe_user_id),
      ]),
    ),
  )

  program.succeed(TrackedPageview(
    id: request.id,
    session_id: maybe_session_id,
    user_id: maybe_user_id,
    route: request.route,
    path: request.path,
  ))
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(pageview_dto.PageviewRequest) {
  program.decode_dynamic(data, pageview_dto.decoder())
}
