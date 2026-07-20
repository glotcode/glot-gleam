import glot_backend/system/effect/error
import glot_backend/system/effect/program
import glot_backend/system/effect/program_types

pub opaque type TotalProgram(a) {
  TotalProgram(inner: program_types.Program(a))
}

pub fn succeed(value: a) -> TotalProgram(a) {
  TotalProgram(program.succeed(value))
}

pub fn from_program(
  effect: program_types.Program(a),
  recover: fn(error.Error) -> a,
) -> TotalProgram(a) {
  effect
  |> program.attempt(fn(err) { program.succeed(recover(err)) })
  |> TotalProgram
}

pub fn map(total_program: TotalProgram(a), f: fn(a) -> b) -> TotalProgram(b) {
  let TotalProgram(inner:) = total_program
  TotalProgram(program.map(inner, f))
}

pub fn and_then(
  total_program: TotalProgram(a),
  f: fn(a) -> TotalProgram(b),
) -> TotalProgram(b) {
  let TotalProgram(inner:) = total_program

  inner
  |> program.and_then(fn(value) {
    let TotalProgram(inner: next_inner) = f(value)
    next_inner
  })
  |> TotalProgram
}

pub fn to_program(total_program: TotalProgram(a)) -> program_types.Program(a) {
  let TotalProgram(inner:) = total_program
  inner
}
