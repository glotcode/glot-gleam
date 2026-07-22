function clickedElement(target) {
  if (target?.nodeType === 1) return target;
  return target?.parentElement ?? null;
}

export function handleModifiedLinkClick(event) {
  const isModified =
    event.metaKey || event.ctrlKey || event.shiftKey || event.altKey;
  if (!isModified) return false;

  const link = clickedElement(event.target)?.closest?.("a[href]");
  if (!link) return false;

  // Modem intercepts all same-origin click events and prevents their default
  // action. Stop its document listener without cancelling the browser action,
  // preserving native new-tab/new-window behavior for modified clicks.
  event.stopImmediatePropagation();
  return true;
}

export function handleSkipLinkClick(event, browserWindow, root) {
  const link = clickedElement(event.target)?.closest?.("a.skip-link[href]");
  if (!link) return false;

  const currentUrl = new URL(browserWindow.location.href);
  const destinationUrl = new URL(link.href, currentUrl);
  const isSameDocument =
    destinationUrl.origin === currentUrl.origin &&
    destinationUrl.pathname === currentUrl.pathname &&
    destinationUrl.search === currentUrl.search;

  if (!isSameDocument || destinationUrl.hash.length < 2) return false;

  let targetId;
  try {
    targetId = decodeURIComponent(destinationUrl.hash.slice(1));
  } catch {
    return false;
  }

  const destination = root.getElementById(targetId);
  if (!destination) return false;

  event.preventDefault();
  event.stopImmediatePropagation();

  if (currentUrl.hash !== destinationUrl.hash) {
    browserWindow.history.pushState(
      {},
      "",
      destinationUrl.pathname + destinationUrl.search + destinationUrl.hash,
    );
  }

  destination.focus({ preventScroll: true });
  destination.scrollIntoView({ block: "start" });
  return true;
}

export function initializeSkipLinks(browserWindow = window, root = document) {
  root.addEventListener(
    "click",
    (event) => {
      if (handleModifiedLinkClick(event)) return;
      handleSkipLinkClick(event, browserWindow, root);
    },
    true,
  );
}
