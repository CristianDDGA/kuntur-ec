import { expect, test } from '@playwright/test';

import { installSoaMock } from '../fixtures/soa-mock';
import {
  attachConsoleGuard,
  clickFlutterButton,
  fillFlutterField,
  flutterText,
  gotoKuntur,
} from '../helpers/flutter-semantics';

test.describe('04 · Modificación, conflicto concurrente 409 y cancelación de reserva', () => {
  test('maneja conflicto 409 al cambiar asientos y luego permite cancelar la reserva', async ({ page }) => {
    const getErrors = attachConsoleGuard(page, { allowHttpStatuses: [409] });
    await installSoaMock(page, { conflictSeatsOnce: ['2C'] });

    await gotoKuntur(page, '/login');
    await fillFlutterField(page, /Correo electrónico/, 'ana@correo.com');
    await fillFlutterField(page, /Contraseña/, 'Clave1234');
    await clickFlutterButton(page, 'Iniciar sesión');
    await expect(flutterText(page, 'Hola, Ana')).toBeVisible();

    // Navega a Mis reservas (barra superior en desktop / barra inferior en móvil)
    await clickFlutterButton(page, /Mis reservas/);
    await expect(flutterText(page, 'KEC-00000058')).toBeVisible();

    await clickFlutterButton(page, /Reserva KEC-00000058/);
    await expect(flutterText(page, 'Detalle del comprobante de venta')).toBeVisible();

    // Cambia asientos intentando tomar 2C (dispara 409 simulado)
    await clickFlutterButton(page, 'Cambiar asientos');
    await expect(flutterText(page, 'Frente del avión')).toBeVisible();
    await clickFlutterButton(page, 'Asiento 2C, disponible');
    await clickFlutterButton(page, 'Guardar cambios');

    // Verifica que la UI muestra el aviso de conflicto y recarga el mapa marcando 2C ocupado
    await expect(flutterText(page, /ya fueron ocupados/)).toBeVisible();

    // Elige 2D disponible y guarda con éxito
    await clickFlutterButton(page, 'Asiento 2D, disponible');
    await clickFlutterButton(page, 'Guardar cambios');
    await expect(flutterText(page, 'Detalle del comprobante de venta')).toBeVisible();

    // Cancela la reserva con hoja de confirmación destructiva
    await clickFlutterButton(page, 'Cancelar reserva');
    await expect(flutterText(page, '¿Cancelar la reserva?')).toBeVisible();
    await clickFlutterButton(page, 'Sí, cancelar');

    await expect(flutterText(page, 'Esta reserva fue cancelada. Los asientos volvieron al vuelo.')).toBeVisible();
    expect(getErrors()).toEqual([]);
  });
});
