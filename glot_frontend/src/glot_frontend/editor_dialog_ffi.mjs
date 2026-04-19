export function openDialog(id) {
  const dialog = document.getElementById(id);

  if (!(dialog instanceof HTMLDialogElement) || dialog.open) {
    return;
  }

  dialog.showModal();
}

export function closeDialog(id) {
  const dialog = document.getElementById(id);

  if (!(dialog instanceof HTMLDialogElement) || !dialog.open) {
    return;
  }

  dialog.close();
}

export function focusElement(id) {
  const element = document.getElementById(id);

  if (!(element instanceof HTMLElement)) {
    return;
  }

  element.focus();
}
