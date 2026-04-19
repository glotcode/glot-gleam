export function readSettings(key) {
  if (typeof window === "undefined" || !window.localStorage) {
    return "";
  }

  return window.localStorage.getItem(key) ?? "";
}

export function writeSettings(key, value) {
  if (typeof window === "undefined" || !window.localStorage) {
    return;
  }

  window.localStorage.setItem(key, value);
}
