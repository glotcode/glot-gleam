import gleam/list
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/transaction/transaction_algebra

pub fn run(p: program_types.Program(a)) -> program_types.Program(a) {
  program_types.Impure(program_types.TransactionEffect(transaction_algebra.Run(p)))
}

pub fn run_all(
  sub_effects: List(program_types.Program(Nil)),
) -> program_types.Program(Nil) {
  run(sequence(sub_effects))
}

fn sequence(
  programs: List(program_types.Program(Nil)),
) -> program_types.Program(Nil) {
  list.fold(programs, program.succeed(Nil), fn(acc, p) {
    program.and_then(acc, fn(_) { p })
  })
}
