import json
from pathlib import Path
import subprocess

import pytest

from mrn import check_digit, is_valid


@pytest.mark.parametrize(
    ("payload", "expected"),
    [("7992739871", "3"), ("12345", "5"), ("0", "0"), ("00000001", "8")],
)
def test_check_digit(payload, expected):
    assert check_digit(payload) == expected
    assert is_valid(payload + expected)


@pytest.mark.parametrize("payload", ["", "12A", "12 3", "-12", "１２", None, 123])
def test_invalid_payload(payload):
    with pytest.raises(ValueError):
        check_digit(payload)


@pytest.mark.parametrize("mrn", ["79927398714", "", "3", "12A", "１２３", None, 123])
def test_invalid_mrn(mrn):
    assert not is_valid(mrn)


GENERATOR = Path(__file__).resolve().parents[1] / "scripts" / "generate-fixtures.js"


def test_synthetic_fixtures():
    result = subprocess.run(
        ["node", str(GENERATOR), "25"], check=True, capture_output=True, text=True
    )
    patients = json.loads(result.stdout)
    assert len(patients) == 25
    assert len({(p["assigningAuthority"], p["mrn"]) for p in patients}) == 25
    assert all(is_valid(p["mrn"]) for p in patients)
    assert all(p["assigningAuthority"] == "SYNTHETIC" for p in patients)
    assert all(p["address"]["country"] == "ZZ" for p in patients)
    assert all(p["givenName"].startswith("Synthetic") for p in patients)


@pytest.mark.parametrize("count", ["0", "-1", "1.5", "10001", "abc", ""])
def test_fixture_count_rejected(count):
    result = subprocess.run(
        ["node", str(GENERATOR), count], capture_output=True, text=True
    )
    assert result.returncode != 0
    assert not result.stdout
