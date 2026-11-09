import pytest
from flask import Flask

from src.presentation.api.responses import ContentNegotiator
from src.presentation.api.serializers.json_serializer import JsonSerializer
from src.presentation.api.serializers.xml_serializer import XmlSerializer


@pytest.fixture
def negotiator():
    return ContentNegotiator((JsonSerializer(), XmlSerializer()), JsonSerializer.mimetype)


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
        ContentNegotiator((XmlSerializer(),), JsonSerializer.mimetype)
