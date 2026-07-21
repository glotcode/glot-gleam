import gleeunit
import glot_frontend/admin/cursor_request

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn beginning_a_request_advances_and_returns_the_same_generation_test() {
  let initial = cursor_request.initial()
  let #(next, request_generation) = cursor_request.begin(initial)

  assert cursor_request.generation(next) == request_generation
  assert cursor_request.generation(initial) != request_generation
}

pub fn consecutive_requests_have_distinct_generations_test() {
  let #(first, first_generation) =
    cursor_request.initial() |> cursor_request.begin
  let #(second, second_generation) = cursor_request.begin(first)

  assert cursor_request.generation(second) == second_generation
  assert first_generation != second_generation
}
