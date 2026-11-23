from datetime import date, datetime, timezone

import pytest

from utils import reloj

# 23 nov 2026 01:17 UTC = 22 nov 20:17 en Ecuador (el caso real que fallaba en Render).
UTC_NOCHE = datetime(2026, 11, 23, 1, 17, tzinfo=timezone.utc)


class _RelojFijo(datetime):
    @classmethod
    def now(cls, tz=None):
        return UTC_NOCHE.astimezone(tz) if tz else UTC_NOCHE.replace(tzinfo=None)


@pytest.fixture
def reloj_en_utc(monkeypatch):
    monkeypatch.setattr(reloj, "datetime", _RelojFijo)


def test_ahora_ecuador_resta_cinco_horas_a_utc(reloj_en_utc):
    assert reloj.ahora_ecuador() == datetime(2026, 11, 22, 20, 17)


def test_ahora_ecuador_no_lleva_zona_como_las_columnas_de_la_base(reloj_en_utc):
    assert reloj.ahora_ecuador().tzinfo is None


def test_hoy_ecuador_sigue_siendo_el_dia_local_aunque_en_utc_ya_sea_manana(reloj_en_utc):
    assert reloj.hoy_ecuador() == date(2026, 11, 22)
