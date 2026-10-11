"""MRN check-digit helpers (Luhn / mod-10) for synthetic numeric MRNs."""

from __future__ import annotations

from dataclasses import dataclass


def luhn_check_digit(payload: str) -> str:
    """Return the check digit to append a numeric payload."""
    if not payload or not payload.isascii() or not payload.isdigit():
        raise ValueError("payload must be a non-empty string of ASCII digits")
    total = 0
    for index, char in enumerate(reversed(payload)):
        digit = int(char)
        if index % 2 == 0:
            digit *= 2
            if digit > 9:
                digit -= 9
        total += digit
    return str((10 - total % 10) % 10)


def is_valid_mrn(mrn: str) -> bool:
    """True when the last digit is the correct check digit for the digits before it."""
    if not isinstance(mrn, str) or len(mrn) < 2:
        return False
    try:
        return luhn_check_digit(mrn[:-1]) == mrn[-1]
    except ValueError:
        return False


@dataclass(frozen=True)
class Mrn:
    """A validated numeric MRN: payload plus check digit."""

    value: str

    def __post_init__(self) -> None:
        if not is_valid_mrn(self.value):
            raise ValueError("Invalid MRN: check digit does not match")

    @classmethod
    def from_payload(cls, payload: str) -> Mrn:
        return cls(payload + luhn_check_digit(payload))

    @property
    def payload(self) -> str:
        return self.value[:-1]

    @property
    def check_digit(self) -> str:
        return self.value[-1]

    def __str__(self) -> str:
        return self.value
