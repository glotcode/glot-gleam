import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/error
import glot_backend/effect/basic/basic
import glot_backend/effect/program_types
import glot_backend/log
import glot_core/email/email_model
import youid/uuid.{type Uuid}

pub fn new_token(length: Int) -> program_types.Program(String) {
  program_types.Impure(
    program_types.BasicEffect(basic.NewToken(length, program_types.Pure)),
  )
}

pub fn system_time() -> program_types.Program(Timestamp) {
  program_types.Impure(
    program_types.BasicEffect(basic.SystemTime(program_types.Pure)),
  )
}

pub fn uuid_v7() -> program_types.Program(Uuid) {
  program_types.Impure(program_types.BasicEffect(basic.UuidV7(program_types.Pure)))
}

pub fn info(fields: log.Fields) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.BasicEffect(
      basic.Log(log.Info, fields, program_types.Pure(Nil)),
    ),
  )
}

pub fn warn(fields: log.Fields) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.BasicEffect(
      basic.Log(log.Warn, fields, program_types.Pure(Nil)),
    ),
  )
}

pub fn send_email(
  message: email_model.Email,
) -> program_types.Program(Result(Nil, error.SendEmailError)) {
  program_types.Impure(
    program_types.BasicEffect(basic.SendEmail(message, program_types.Pure)),
  )
}
