"""Name normalization helpers. Display form is preserved; matching keys are for search only."""
from __future__ import annotations

import re
import unicodedata

_WHITESPACE = re.compile(r"\s+")

def normalize_name(raw: str) -> str:
    """Canonical display form: NFC, no control characters, single spaces, trimmed. Capitalisation and punctuation are kept exactly as given: never "correct" someone's name."""
    if not isinstance(raw, str):
        raise TypeError("name must be a string")
    text = unicodedata.normalize("NFC", raw)
    text = "".join(ch for ch in text if ch.isspace() or unicodedata.category(ch) != "Cc")
    return _WHITESPACE.sub(" ", text).strip()

def name_match_key(raw: str) -> str:
    """Loose key for finding *candidate* matches (case, accents, punctuation ignored). Never use this to decide that two records are the same person."""
    decomposed = unicodedata.normalize("NFKD", normalize_name(raw))
    unaccented = "".join(ch for ch in decomposed if not unicodedata.combining(ch))
    letters = "".join(ch if ch.isalnum() else " " for ch in unaccented.casefold())
    return _WHITESPACE.sub(" ", letters).strip()