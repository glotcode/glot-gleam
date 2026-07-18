export const cookieNoticeStorageKey = "glot.cookie-notice.seen";

export function noticeWasSeen(storage) {
  try {
    return storage?.getItem(cookieNoticeStorageKey) === "true";
  } catch {
    return false;
  }
}

export function rememberNotice(storage) {
  try {
    storage?.setItem(cookieNoticeStorageKey, "true");
  } catch {
    // The notice can still be dismissed for this page when storage is blocked.
  }
}

export function forgetNotice(storage) {
  try {
    storage?.removeItem(cookieNoticeStorageKey);
  } catch {
    // A blocked storage API should not prevent the notice from opening.
  }
}
