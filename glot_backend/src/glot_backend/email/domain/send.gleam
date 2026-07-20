import glot_backend/email/effect/delivery/effect as email_effect
import glot_backend/system/effect/basic/basic_effect
import glot_backend/system/effect/log
import glot_backend/system/effect/program
import glot_backend/system/effect/program_types
import glot_backend/system/request/context
import glot_core/email/email_model

pub fn send_email(
  _ctx: context.Context,
  email: email_model.Email,
) -> program_types.Program(Nil) {
  use send_result <- program.and_then(email_effect.send_email(email))

  case send_result {
    Ok(result) -> {
      use _ <- program.and_then(
        basic_effect.info(
          log.from_list([
            log.object("send_email_result", [
              log.string_list("delivered", result.delivered),
              log.string_list("permanent_bounces", result.permanent_bounces),
              log.string_list("queued", result.queued),
            ]),
          ]),
        ),
      )

      program.succeed(Nil)
    }
    Error(err) -> program.fail(err)
  }
}

pub fn email_from_json(
  ctx: context.Context,
  json_str: String,
) -> program_types.Program(email_model.Email) {
  program.parse_json(json_str, email_model.decoder(ctx.regexes.is_email))
}
