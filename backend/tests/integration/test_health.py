def test_health_responde_json_por_defecto(client):
    resp = client.get("/api/health")
    assert resp.status_code == 200
    assert resp.mimetype == "application/json"
    assert resp.get_json()["estado"] == "ok"


def test_health_responde_xml_si_se_solicita(client):
    resp = client.get("/api/health", headers={"Accept": "application/xml"})
    assert resp.status_code == 200
    assert resp.mimetype == "application/xml"
    assert "<estado>ok</estado>" in resp.get_data(as_text=True)


def test_ruta_inexistente_devuelve_error_uniforme(client):
    resp = client.get("/api/no-existe")
    assert resp.status_code == 404
    assert resp.get_json()["error"] == "not_found"
