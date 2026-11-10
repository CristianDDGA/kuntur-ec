import pytest
from flask import Flask

from utils.formatos import JsonFormato, XmlFormato
from utils.respuestas import ContentNegotiator


@pytest.fixture
def negotiator():
    return ContentNegotiator((JsonFormato(), XmlFormato()), JsonFormato.mimetype)


@pytest.mark.parametrize(
    ("accept", "esperado"),
    [
        ("application/xml", "application/xml"),
        ("application/json", "application/json"),
        ("*/*", "application/json"),
        ("text/html", "application/json"),
    ],
)
def test_selecciona_formato_segun_accept(negotiator, accept, esperado):
    with Flask(__name__).test_request_context(headers={"Accept": accept}):
        assert negotiator.select().mimetype == esperado


def test_formato_por_defecto_debe_estar_registrado():
    with pytest.raises(ValueError):
        ContentNegotiator((XmlFormato(),), JsonFormato.mimetype)
