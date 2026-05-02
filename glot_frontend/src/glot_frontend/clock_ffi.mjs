export function nowMilliseconds() {
  return Date.now();
}

export function waitUntilNextMinute(onTick) {
  const delayMs = 60_000 - (Date.now() % 60_000);

  setTimeout(() => {
    onTick(Date.now());
  }, delayMs);
}
