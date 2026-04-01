import glot_backend/effect/error
import glot_backend/effect/interpreter
import glot_backend/effect/runtime_types
import glot_backend/effect/types

pub type Program(a) =
  types.Program(a)

pub type DbQueryError =
  error.DbQueryError

pub type DbCommandError =
  error.DbCommandError

pub type DbTransactionError =
  error.DbTransactionError

pub type RunRequestError =
  error.RunRequestError

pub type LoginError =
  error.LoginError

pub type SendEmailError =
  error.SendEmailError

pub type SessionError =
  error.SessionError

pub type Error =
  error.Error

pub type DbQueryName =
  types.DbQueryName

pub type DbCommandName =
  types.DbCommandName

pub type EffectName =
  types.EffectName

pub type EffectTiming =
  types.EffectTiming

pub type State =
  types.State

pub type Handlers =
  runtime_types.Handlers

pub fn run(
  effect: Program(a),
  handlers: Handlers,
) -> #(Result(a, Error), State) {
  interpreter.run(effect, handlers)
}
