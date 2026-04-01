import glot_backend/effect/error
import glot_backend/effect/effect_model
import glot_backend/effect/interpreter
import glot_backend/effect/handlers_types

pub type Program(a) =
  effect_model.Program(a)

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
  effect_model.DbQueryName

pub type DbCommandName =
  effect_model.DbCommandName

pub type EffectName =
  effect_model.EffectName

pub type EffectTiming =
  effect_model.EffectTiming

pub type State =
  effect_model.State

pub type Handlers =
  handlers_types.Handlers

pub fn run(
  effect: Program(a),
  handlers: Handlers,
) -> #(Result(a, Error), State) {
  interpreter.run(effect, handlers)
}
