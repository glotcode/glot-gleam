function pad(value) {
  return String(value).padStart(2, "0");
}

function toDate(seconds, nanoseconds) {
  const milliseconds = seconds * 1000 + Math.floor(nanoseconds / 1_000_000);
  return new Date(milliseconds);
}

export function timestampToLocalDateInput(seconds, nanoseconds) {
  const date = toDate(seconds, nanoseconds);

  return [
    String(date.getFullYear()).padStart(4, "0"),
    pad(date.getMonth() + 1),
    pad(date.getDate()),
  ].join("-");
}

export function timestampToLocalTimeInput(seconds, nanoseconds) {
  const date = toDate(seconds, nanoseconds);

  return [pad(date.getHours()), pad(date.getMinutes()), pad(date.getSeconds())].join(":");
}

export function localDateTimeToUnixMilliseconds(date, time) {
  if (!date || !time) return -1;

  const parsed = new Date(`${date}T${time}`);
  const milliseconds = parsed.getTime();

  return Number.isNaN(milliseconds) ? -1 : milliseconds;
}
