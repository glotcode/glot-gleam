pub fn document_is_visible() -> Bool {
  is_document_visible()
}

@external(javascript, "./page_visibility_ffi.mjs", "isDocumentVisible")
fn is_document_visible() -> Bool
