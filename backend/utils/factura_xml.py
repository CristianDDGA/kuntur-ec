"""Factura de una reserva en XML, con el mismo método visto en clase (practica-xml):

1. Se arma un JSON con la estructura de la factura (factura, cliente, detalles).
2. Con ese JSON se construye el XML usando xml.etree.ElementTree, sección por
   sección con SubElement, y se le da formato con minidom.

Diferencia con la práctica: allí el cliente (Flutter) enviaba los montos en el JSON.
Aquí el JSON se arma en el servidor con los montos guardados en la reserva, para que
nadie pueda generarse una factura con un total inventado.
"""
from __future__ import annotations

import xml.etree.ElementTree as ET
from typing import Any
from xml.dom import minidom

from models import Usuario
from models.tarifa_iva import redondear
from services.reserva_service import ReservaDetalle
from utils.formatos import to_primitive


def numero_factura(reserva_id: int) -> str:
    """KEC-00000058: número único y legible derivado del id de la reserva."""
    return f"KEC-{reserva_id:08d}"


# =============================
# 1. JSON de la factura
# =============================

def armar_datos_factura(detalle: ReservaDetalle, cliente: Usuario) -> dict[str, Any]:
    """Mismo formato del JSON que se usó en clase: factura, cliente y detalles."""
    reserva, vuelo = detalle.reserva, detalle.vuelo
    datos = {
        "factura": {
            "numero": numero_factura(reserva.id),  # type: ignore[arg-type]
            "fecha": reserva.fecha_reserva.date() if reserva.fecha_reserva else None,
        },
        "cliente": {"nombre": cliente.nombre, "correo": cliente.correo},
        "detalles": [
            {
                "nombre": (
                    f"Pasaje {vuelo.codigo} {vuelo.origen} - {vuelo.destino} "
                    f"({vuelo.fecha} {vuelo.hora_salida:%H:%M})"
                ),
                "cantidad": reserva.cantidad_asientos,
                "precio": redondear(reserva.subtotal / reserva.cantidad_asientos),
                "subtotal": reserva.subtotal,
            }
        ],
        "totales": {
            "subtotal": reserva.subtotal,
            "porcentaje_iva": reserva.iva_porcentaje,
            "iva": reserva.iva_valor,
            "total": reserva.total,
        },
        "estado": reserva.estado.value.capitalize(),
    }
    return to_primitive(datos)  # montos como "89.00", fechas ISO: listo para JSON o XML


# =============================
# 2. XML a partir del JSON
# =============================

def generar_factura_xml(datos: dict[str, Any]) -> str:
    # Sección de la cabecera
    factura = ET.Element("factura")
    cabecera = ET.SubElement(factura, "cabecera")
    ET.SubElement(cabecera, "numero").text = datos["factura"]["numero"]
    ET.SubElement(cabecera, "fecha").text = datos["factura"]["fecha"]

    # Parte del cliente
    cliente = ET.SubElement(factura, "cliente")
    ET.SubElement(cliente, "nombre").text = datos["cliente"]["nombre"]
    ET.SubElement(cliente, "correo").text = datos["cliente"]["correo"]

    # Sección del detalle
    detalle = ET.SubElement(factura, "Detalle")
    for item in datos["detalles"]:
        producto = ET.SubElement(detalle, "producto")
        ET.SubElement(producto, "Nombre").text = item["nombre"]
        ET.SubElement(producto, "Cantidad").text = str(item["cantidad"])
        ET.SubElement(producto, "PrecioUnitario").text = item["precio"]
        ET.SubElement(producto, "Subtotal").text = item["subtotal"]

    # Totales (los guardados en la reserva, no se recalculan)
    totales = ET.SubElement(factura, "Totales")
    ET.SubElement(totales, "Subtotal").text = datos["totales"]["subtotal"]
    ET.SubElement(totales, "PorcentajeIVA").text = datos["totales"]["porcentaje_iva"]
    ET.SubElement(totales, "IVA").text = datos["totales"]["iva"]
    ET.SubElement(totales, "Total").text = datos["totales"]["total"]

    ET.SubElement(factura, "Estado").text = datos["estado"]

    xml_sin_formato = ET.tostring(factura, encoding="utf-8", method="xml")
    return minidom.parseString(xml_sin_formato).toprettyxml(indent="  ", encoding="utf-8").decode("utf-8")
