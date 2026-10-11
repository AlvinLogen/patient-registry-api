import json
from pathlib import Path

import pytest  # pyright: ignore[reportMissingImports]

from patient_registry.mrn import Mrn, is_valid_mrn, luhn_check_digit

VECTORS_PATH = (
    Path(__file__).resolve().parents[2]
    / "fixtures"
    / "vectors"
    / "mrn-check-digit.json"
)
VECTORS = json.loads(VECTORS_PATH.read_text(encoding="utf-8"))


@pytest.mark.parametrize("case", VECTORS["valid"], ids=lambda case: case["payload"])
def test_check_digit_matches_shared_vector(case):
    assert luhn_check_digit(case["payload"]) == case["checkDigit"]


@pytest.mark.parametrize("case", VECTORS["valid"], ids=lambda case: case["payload"])
def test_payload_plus_check_digit_is_a_valid_mrn(case):
    assert is_valid_mrn(case["payload"] + case["checkDigit"]) is True


@pytest.mark.parametrize("mrn", VECTORS["invalidMrns"], ids=repr)
def test_invalid_mrns_are_rejected(mrn):
    assert is_valid_mrn(mrn) is False


@pytest.mark.parametrize("payload", ["", "12a4", "12 4", "\u0661\u0662\u0663"])
def test_check_digit_rejects_non_ascii_digit_payloads(payload):
    with pytest.raises(ValueError):
        luhn_check_digit(payload)


def test_mrn_is_a_value_object():
    mrn = Mrn.from_payload("1000001")
    assert str(mrn) == "10000016"
    assert (mrn.payload, mrn.check_digit) == ("1000001", "6")
    assert mrn == Mrn("10000016")
    assert len({mrn, Mrn("10000016")}) == 1


def test_mrn_rejects_a_wrong_check_digit_without_leaking_the_value():
    with pytest.raises(ValueError) as excinfo:
        Mrn("10000015")
    assert "10000015" not in str(excinfo.value)
