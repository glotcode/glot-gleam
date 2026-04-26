function bindBackdropClose(dialog) {
  if (dialog.dataset.appDialogBound === "true") {
    return;
  }

  dialog.addEventListener("click", (event) => {
    const rect = dialog.getBoundingClientRect();
    const clickedInside =
      rect.left <= event.clientX &&
      event.clientX <= rect.right &&
      rect.top <= event.clientY &&
      event.clientY <= rect.bottom;

    if (!clickedInside) {
      dialog.close();
    }
  });

  dialog.dataset.appDialogBound = "true";
}

export function openDialog(id) {
  const dialog = document.getElementById(id);

  if (!(dialog instanceof HTMLDialogElement)) {
    return;
  }

  bindBackdropClose(dialog);

  if (dialog.open) {
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
