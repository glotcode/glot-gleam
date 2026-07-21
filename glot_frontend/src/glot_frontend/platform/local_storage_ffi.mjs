function storage() {
  if (typeof window === "undefined") {
    return null;
  }

  try {
    return window.localStorage;
  } catch {
    return null;
  }
}

export function getItem(key) {
  try {
    const value = storage()?.getItem(key);
    return value === null || value === undefined
      ? [false, ""]
      : [true, value];
  } catch {
    return [false, ""];
  }
}

export function setItem(key, value) {
  try {
    const target = storage();
    if (!target) return false;
    target.setItem(key, value);
    return true;
  } catch {
    return false;
  }
}

export function removeItem(key) {
  try {
    const target = storage();
    if (!target) return false;
    target.removeItem(key);
    return true;
  } catch {
    return false;
  }
}
