let shortcutsBound = false;

function shouldIgnoreTarget(target) {
  if (
    !(target instanceof HTMLElement) ||
    target.isContentEditable
  ) {
    return false;
  }

  const tag = target.tagName;

  return (
    tag === "INPUT" ||
    tag === "TEXTAREA" ||
    tag === "SELECT"
  );
}

export function bindShortcuts(onQuickActions) {
  if (shortcutsBound || typeof document === "undefined") {
    return;
  }

  document.addEventListener("keydown", (event) => {
    if (
      event.key.toLowerCase() !== "k" ||
      event.altKey ||
      event.shiftKey ||
      !(event.metaKey || event.ctrlKey) ||
      shouldIgnoreTarget(event.target)
    ) {
      return;
    }

    event.preventDefault();
    onQuickActions();
  });

  shortcutsBound = true;
}
