"""Luhn check digits for numeric medical record numbers (MRNs)."""


def check_digit(payload: str) -> str:
    """Return the Luhn digit to append to an ASCII-digit payload."""
    if not isinstance(payload, str) or not payload or not payload.isascii() or not payload.isdigit():
        raise ValueError("MRN payload must contain only ASCII digits")
    total = 0
    for index, character in enumerate(reversed(payload)):
        digit = int(character)
        if index % 2 == 0:
            digit *= 2
            if digit > 9:
                digit -= 9
        total += digit
    return str((-total) % 10)


def is_valid(mrn: str) -> bool:
    """Return whether an MRN includes a valid trailing Luhn check digit."""
    return (
        isinstance(mrn, str)
        and len(mrn) > 1
        and mrn.isascii()
        and mrn.isdigit()
        and check_digit(mrn[:-1]) == mrn[-1]
    )
