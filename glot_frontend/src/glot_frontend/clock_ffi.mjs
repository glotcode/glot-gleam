export function nowMilliseconds() {
  return Date.now();
}

export function waitUntilNextTick(onTick) {
  const delayMs = 10_000 - (Date.now() % 10_000);

  setTimeout(() => {
    onTick(Date.now());
  }, delayMs);
}
