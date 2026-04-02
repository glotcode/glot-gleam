import glot_backend/context
import glot_backend/effect/auth/auth
import glot_backend/effect/basic/basic
import glot_backend/effect/docker_run/docker_run
import glot_backend/effect/error
import glot_backend/effect/job/job
import glot_backend/effect/program_state
import glot_backend/effect/snippet/snippet
import glot_backend/effect/user_action/user_action
import pog

pub type Program(a) {
  Pure(a)
  Fail(error.Error)
  Impure(Effect(Program(a)))
}

pub type Effect(next) {
  BasicEffect(basic.BasicEffect(next))
  JobEffect(job.JobEffect(next))
  AuthEffect(auth.AuthEffect(next))
  SnippetEffect(snippet.SnippetEffect(next))
  DockerRunEffect(docker_run.DockerRunEffect(next))
  UserActionEffect(user_action.UserActionEffect(next))
  TransactionEffect(
    fn(pog.Connection, context.Context) ->
      #(next, program_state.State),
  )
}
