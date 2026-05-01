const newSnippetStorageKey = languageSlug =>
  `glot.editor.draft.new.${languageSlug}`;

const existingSnippetStorageKey = slug => `glot.editor.draft.snippet.${slug}`;

export function loadNewSnippetDraft(languageSlug, maxAgeMs) {
  return loadDraft(newSnippetStorageKey(languageSlug), maxAgeMs);
}

export function writeNewSnippetDraft(languageSlug, value) {
  writeDraft(newSnippetStorageKey(languageSlug), value);
}

export function clearNewSnippetDraft(languageSlug) {
  clearDraft(newSnippetStorageKey(languageSlug));
}

export function loadExistingSnippetDraft(slug, maxAgeMs) {
  return loadDraft(existingSnippetStorageKey(slug), maxAgeMs);
}

export function writeExistingSnippetDraft(slug, value) {
  writeDraft(existingSnippetStorageKey(slug), value);
}

export function clearExistingSnippetDraft(slug) {
  clearDraft(existingSnippetStorageKey(slug));
}

function loadDraft(key, maxAgeMs) {
  if (typeof window === "undefined" || !window.localStorage) {
    return "";
  }

  const raw = window.localStorage.getItem(key);

  if (!raw) {
    return "";
  }

  try {
    const parsed = JSON.parse(raw);

    if (
      typeof parsed.savedAtMs !== "number"
      || Date.now() - parsed.savedAtMs > maxAgeMs
    ) {
      window.localStorage.removeItem(key);
      return "";
    }

    return JSON.stringify(parsed);
  } catch {
    window.localStorage.removeItem(key);
    return "";
  }
}

function writeDraft(key, value) {
  if (typeof window === "undefined" || !window.localStorage) {
    return;
  }

  try {
    window.localStorage.setItem(
      key,
      JSON.stringify({
        savedAtMs: Date.now(),
        data: JSON.parse(value),
      }),
    );
  } catch {
    window.localStorage.removeItem(key);
  }
}

function clearDraft(key) {
  if (typeof window === "undefined" || !window.localStorage) {
    return;
  }

  window.localStorage.removeItem(key);
}
