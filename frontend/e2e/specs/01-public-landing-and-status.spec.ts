import { expect, test } from '@playwright/test';

import { installSoaMock } from '../fixtures/soa-mock';
import {
  attachConsoleGuard,
  clickFlutterButton,
  expectNoHorizontalOverflow,
  flutterText,
  gotoKuntur,
} from '../helpers/flutter-semantics';

test.describe('01 · Portada pública, estado SOA y ruta 404', () => {
  test('muestra las 4 regiones, navega por destino popular hacia login y consulta /estado sin sesión', async ({ page }) => {
    const getErrors = attachConsoleGuard(page);
    await installSoaMock(page);

    await gotoKuntur(page, '/');

    await expect(flutterText(page, 'Descubre las 4 regiones del Ecuador')).toBeVisible();
    await expect(flutterText(page, 'Sierra Andina')).toBeVisible();
    await expect(flutterText(page, 'Explorar vuelos')).toBeVisible();
    await expectNoHorizontalOverflow(page);

    // Avanza manualmente el carrusel de regiones
    await clickFlutterButton(page, 'Siguiente región');
    await expect(flutterText(page, 'Costa del Pacífico')).toBeVisible();

    // Selecciona un destino popular: debe pre-cargar contexto en /login
    await clickFlutterButton(page, /Vuelos hacia Guayaquil/);
    await expect(flutterText(page, 'Bienvenido de vuelta')).toBeVisible();
    await expect(flutterText(page, /Inicie sesión para ver vuelos disponibles hacia Guayaquil/)).toBeVisible();

    // Vuelve al inicio desde el botón de retorno y consulta /estado sin sesión
    await clickFlutterButton(page, /Volver al inicio/);
    await expect(flutterText(page, 'Descubre las 4 regiones del Ecuador')).toBeVisible();

    await gotoKuntur(page, '/estado');
    await expect(flutterText(page, 'Estado del servicio')).toBeVisible();
    await expect(flutterText(page, 'API conectada')).toBeVisible();

    // Regresa al inicio desde las migas táctiles
    await clickFlutterButton(page, /Ir a Inicio/);
    await expect(flutterText(page, 'Descubre las 4 regiones del Ecuador')).toBeVisible();

    // Verifica guardia de ruta desconocida sin sesión: redirige de forma segura a /login
    await gotoKuntur(page, '/ruta-inexistente-kuntur');
    await expect(flutterText(page, 'Bienvenido de vuelta')).toBeVisible();
    await clickFlutterButton(page, /Volver al inicio/);
    await expect(flutterText(page, 'Descubre las 4 regiones del Ecuador')).toBeVisible();

    expect(getErrors()).toEqual([]);
  });
});
