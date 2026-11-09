"""Contrato común de los serializadores de respuesta (estrategia)."""
from abc import ABC, abstractmethod
from typing import Any


class ResponseSerializer(ABC):
    """Convierte un dict/list en el cuerpo de una respuesta HTTP."""

    mimetype: str

    @abstractmethod
    def serialize(self, data: Any, root: str = "respuesta") -> str: ...
