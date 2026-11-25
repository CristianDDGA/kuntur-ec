import { expect, test } from '@playwright/test';

import { installSoaMock } from '../fixtures/soa-mock';
import {
  attachConsoleGuard,
  clickFlutterButton,
  fillFlutterField,
  flutterText,
  gotoKuntur,
} from '../helpers/flutter-semantics';

test.describe('03 · Flujo completo de cliente: búsqueda, asientos 3×3, reserva y factura XML', () => {
  test('filtra vuelos, reserva 2 asientos y visualiza factura legible + documento XML', async ({ page }) => {
    const getErrors = attachConsoleGuard(page);
    await installSoaMock(page);

    await gotoKuntur(page, '/login');
    await fillFlutterField(page, /Correo electrónico/, 'ana@correo.com');
    await fillFlutterField(page, /Contraseña/, 'Clave1234');
    await clickFlutterButton(page, 'Iniciar sesión');

    await expect(flutterText(page, 'Hola, Ana')).toBeVisible();

    // Filtrado de vuelos hacia Guayaquil
    await fillFlutterField(page, /^Destino$/, 'Guayaquil');
    await clickFlutterButton(page, 'Buscar vuelos');
    await expect(flutterText(page, '1 vuelo disponible')).toBeVisible();

    // Abre detalle del vuelo KT101
    await clickFlutterButton(page, /Vuelo KT101 de Quito a Guayaquil/);
    await expect(flutterText(page, '$ 75.50')).toBeVisible();

    // Entra a selección de asientos 3×3
    await clickFlutterButton(page, /Elegir asientos/);
    await expect(flutterText(page, 'Frente del avión')).toBeVisible();

    // Selecciona 2 asientos disponibles (2A y 2B)
    await clickFlutterButton(page, 'Asiento 2A, disponible');
    await clickFlutterButton(page, 'Asiento 2B, disponible');

    // Verifica cálculo en vivo: 2 × 75.50 = 151.00 + 15% IVA (22.65) = $ 173.65
    await expect(flutterText(page, '$ 173.65')).toBeVisible();

    // Confirma la reserva
    await clickFlutterButton(page, 'Confirmar reserva');

    // Llega al detalle de la nueva reserva y navega al Comprobante (Factura + XML)
    await expect(flutterText(page, 'Detalle del comprobante de venta')).toBeVisible();
    await clickFlutterButton(page, /Ver comprobante/);

    await expect(flutterText(page, 'Comprobante de venta')).toBeVisible();
    await expect(flutterText(page, '$ 173.65')).toBeVisible();

    // Alterna al tab Factura XML (SelectorLiquidMorph ahora 100% accesible vía Semantics.onTap)
    await clickFlutterButton(page, 'Factura XML');
    await expect(flutterText(page, 'Copiar XML')).toBeVisible();
    await expect(flutterText(page, 'Descargar factura (XML)')).toBeVisible();

    // Dispara descarga del archivo .xml
    const downloadPromise = page.waitForEvent('download');
    await clickFlutterButton(page, 'Descargar factura (XML)');
    const download = await downloadPromise;
    expect(download.suggestedFilename()).toMatch(/^factura-KEC-\d+\.xml$/);

    expect(getErrors()).toEqual([]);
  });
});
