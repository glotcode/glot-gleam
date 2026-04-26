export function scrollToSelected(index) {
  if (typeof document === "undefined") {
    return;
  }

  const dialog = document.getElementById("app-quick-actions-dialog");

  if (!(dialog instanceof HTMLDialogElement) || !dialog.open) {
    return;
  }

  const selected = dialog.querySelector(
    `[data-quick-action-index="${index}"]`,
  );

  if (!(selected instanceof HTMLElement)) {
    return;
  }

  selected.scrollIntoView({
    block: "nearest",
    inline: "nearest",
  });
}
