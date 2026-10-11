import pytest  # pyright: ignore[reportMissingImports]

from patient_registry.names import name_match_key, normalize_name


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("  Alex   Testfamily ", "Alex Testfamily"),
        ("Anna\tMaria\n", "Anna Maria"),
        ("Jose\u0301", "Jos\u00e9"),
        ("A\x00nna", "Anna"),
        ("   ", ""),
        ("McTest", "McTest"),
        ("van der Fixture", "van der Fixture"),
        ("O'Testington", "O'Testington"),
    ],
)
def test_normalize_name_cleans_but_never_rewrites(raw, expected):
    assert normalize_name(raw) == expected


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("Jos\u00e9 da Silva", "jose da silva"),
        ("O'Testington", "o testington"),
        ("Anne-Marie", "anne marie"),
        ("M\u00fcller", "muller"),
        ("Stra\u00dfe", "strasse"),
        ("  Alex   Test ", "alex test"),
        ("", ""),
    ],
)
def test_name_match_key_ignores_case_accents_and_punctuation(raw, expected):
    assert name_match_key(raw) == expected


def test_normalise_name_rejects_non_strings():
    with pytest.raises(TypeError):
        normalize_name(None)  # pyright: ignore[reportArgumentType]
