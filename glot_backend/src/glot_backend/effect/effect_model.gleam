import glot_backend/effect/auth/auth
import glot_backend/effect/core/core
import glot_backend/effect/docker_run/docker_run
import glot_backend/effect/error
import glot_backend/effect/snippet/snippet

pub type Program(a) {
  Pure(a)
  Fail(error.Error)
  Impure(Effect(Program(a)))
}

pub type DbQueryName {
  CoreQueryName(core.CoreQueryName)
  AuthQueryName(auth.AuthQueryName)
}

pub type DbCommandName {
  CoreCommandName(core.CoreCommandName)
  AuthCommandName(auth.AuthCommandName)
  SnippetCommandName(snippet.SnippetCommandName)
}

pub type EffectName {
  NewTokenEffect
  SystemTimeEffect
  UuidV7Effect
  LogEffect
  DockerRunRequestEffect
  SendEmailEffect
  RunQueryEffect(DbQueryName)
  RunCommandEffect(DbCommandName)
  RunInTransactionEffect(List(EffectName))
}

pub type EffectTiming =
  #(EffectName, Int)

pub type Effect(next) {
  CoreEffect(core.CoreEffect(next))
  AuthEffect(auth.AuthEffect(next))
  SnippetEffect(snippet.SnippetEffect(next))
  DockerRunEffect(docker_run.DockerRunEffect(next))
  TransactionEffect(
    List(Program(Nil)),
    fn(Result(Nil, error.DbTransactionError)) -> next,
  )
}
