import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/basic/basic_algebra
import glot_backend/effect/program_types
import glot_backend/log
import youid/uuid.{type Uuid}

pub fn new_token(length: Int) -> program_types.Program(String) {
  program_types.Impure(
    program_types.BasicEffect(basic_algebra.NewToken(length, program_types.Pure)),
  )
}

pub fn system_time() -> program_types.Program(Timestamp) {
  program_types.Impure(
    program_types.BasicEffect(basic_algebra.SystemTime(program_types.Pure)),
  )
}

pub fn uuid_v7() -> program_types.Program(Uuid) {
  program_types.Impure(
    program_types.BasicEffect(basic_algebra.UuidV7(program_types.Pure)),
  )
}

pub fn info(fields: log.Fields) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.BasicEffect(basic_algebra.Log(
      log.Info,
      fields,
      program_types.Pure(Nil),
    )),
  )
}

pub fn warn(fields: log.Fields) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.BasicEffect(basic_algebra.Log(
      log.Warn,
      fields,
      program_types.Pure(Nil),
    )),
  )
}

pub fn debug(fields: log.Fields) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.BasicEffect(basic_algebra.Log(
      log.Debug,
      fields,
      program_types.Pure(Nil),
    )),
  )
}
