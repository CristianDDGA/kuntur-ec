import { expect, test } from '@playwright/test';

import { installSoaMock } from '../fixtures/soa-mock';
import {
  attachConsoleGuard,
  clickFlutterButton,
  expectNoHorizontalOverflow,
  fillFlutterField,
  flutterText,
  gotoKuntur,
} from '../helpers/flutter-semantics';

test.describe('06 · Responsividad adaptativa, accesibilidad y estrés de datos (break-ui)', () => {
  test('adapta navegación en desktop (>=1024px) vs móvil (375px/320px) y soporta datos extremos', async ({ page }, testInfo) => {
    const getErrors = attachConsoleGuard(page);
    await installSoaMock(page, { worstCaseData: true });

    await gotoKuntur(page, '/login');
    await fillFlutterField(page, /Correo electrónico/, 'aleksandra@northwind.example.com');
    await fillFlutterField(page, /Contraseña/, 'Clave1234');
    await clickFlutterButton(page, 'Iniciar sesión');

    // Verifica que el nombre largo y los montos altos ($ 2,240.00) renderizan sin desbordar
    await expect(flutterText(page, 'KT901')).toBeVisible();
    await expect(flutterText(page, '$ 2,240.00')).toBeVisible();
    await expectNoHorizontalOverflow(page);

    if (testInfo.project.name === 'desktop-chromium') {
      // En escritorio 1440px, las secciones principales viven en la barra superior
      await expect(page.getByRole('button', { name: 'Vuelos', exact: true })).toBeVisible();
      await expect(page.getByRole('button', { name: 'Mis reservas', exact: true })).toBeVisible();
    }

    // Revisa historial de reservas con monto $ 25,760.00 y ciudad larga
    await clickFlutterButton(page, /Mis reservas/);
    await expect(flutterText(page, '$ 25,760.00')).toBeVisible();
    await expectNoHorizontalOverflow(page);

    // En móvil, verifica además viewport ultra estrecho de 320px
    if (testInfo.project.name === 'mobile-chromium') {
      await page.setViewportSize({ width: 320, height: 568 });
      await expectNoHorizontalOverflow(page);
    }

    expect(getErrors()).toEqual([]);
  });
});
