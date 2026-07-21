import gleam/option
import gleam/string
import gleeunit
import glot_core/run
import glot_frontend/public/editor/execution
import lustre/element

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn output_streams_render_distinct_semantic_colors_test() {
  let rendered =
    execution.view(
      option.None,
      execution.Completed(
        Ok(run.SuccessfulRun(
          duration: 1_000_000,
          stdout: "standard output",
          stderr: "standard error",
          error: "runtime error",
        )),
      ),
      execution.SaveIdle,
    )
    |> element.to_document_string

  assert string.contains(rendered, "editor-shell__result-header--stdout")
  assert string.contains(rendered, "editor-shell__result-header--stderr")
  assert string.contains(rendered, "editor-shell__result-header--error")
}
