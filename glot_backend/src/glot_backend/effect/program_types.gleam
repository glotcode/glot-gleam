import glot_backend/context
import glot_backend/effect/auth/auth
import glot_backend/effect/core/core
import glot_backend/effect/docker_run/docker_run
import glot_backend/effect/error
import glot_backend/effect/job/job
import glot_backend/effect/program_state
import glot_backend/effect/snippet/snippet
import pog

pub type Program(a) {
  Pure(a)
  Fail(error.Error)
  Impure(Effect(Program(a)))
}

pub type Effect(next) {
  CoreEffect(core.CoreEffect(next))
  JobEffect(job.JobEffect(next))
  AuthEffect(auth.AuthEffect(next))
  SnippetEffect(snippet.SnippetEffect(next))
  DockerRunEffect(docker_run.DockerRunEffect(next))
  TransactionEffect(
    fn(pog.Connection, context.Context) ->
      #(next, program_state.State),
  )
}
