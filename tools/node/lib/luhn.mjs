const DIGITS = /^[0-9]+$/;

export function luhnCheckDigit(payload) {
  if (typeof payload !== "string" || !DIGITS.test(payload)) {
    throw new RangeError("payload must be a non-empty string of ASCII digits");
  }

  let total = 0;

  for (let i = 0; i < payload.length; i += 1) {
    let digit = Number(payload[payload.length - 1 - i]);
    if (i % 2 === 0) {
      digit *= 2;
      if (digit > 9) digit -= 9;
    }

    total += digit;
  }

  return String((10 - (total % 10)) % 10);
}

export function isValidMrn(mrn) {
  if (typeof mrn !== "string" || mrn.length < 2) return false;

  const payload = mrn.slice(0, -1);
  return DIGITS.test(payload) && luhnCheckDigit(payload) === mrn.at(-1);
}
