import { expect, test } from '@playwright/test';

import { installSoaMock } from '../fixtures/soa-mock';
import {
  attachConsoleGuard,
  clickFlutterButton,
  fillFlutterField,
  flutterText,
  gotoKuntur,
} from '../helpers/flutter-semantics';

test.describe('05 · Operaciones de administrador: KPIs, gestión de vuelos, 409 optimista y flota', () => {
  test('consulta resumen de ventas, gestiona vuelos, maneja 409 y cancela vuelo con motivo', async ({ page }) => {
    const getErrors = attachConsoleGuard(page, { allowHttpStatuses: [409] });
    await installSoaMock(page, { conflictFlightVersionOnce: true });

    await gotoKuntur(page, '/login');
    await fillFlutterField(page, /Correo electrónico/, 'admin@kuntur.ec');
    await fillFlutterField(page, /Contraseña/, 'Admin1234');
    await clickFlutterButton(page, 'Iniciar sesión');

    await expect(flutterText(page, 'Hola, Administrador')).toBeVisible();

    // Navega al panel de Administración
    await clickFlutterButton(page, /Administración/);
    await expect(flutterText(page, 'Resumen de ventas')).toBeVisible();
    await expect(flutterText(page, 'Ingresos totales')).toBeVisible();

    // Desplaza suavemente para validar la tarjeta de IVA vigente incluso en móvil (375×812)
    await page.mouse.move(200, 400);
    await page.mouse.wheel(0, 700);
    await expect(flutterText(page, 'IVA vigente')).toBeVisible();
    await expect(flutterText(page, '15 %')).toBeVisible();
    await page.mouse.wheel(0, -700);

    // Abre Importar aviones y verifica la flota registrada
    await clickFlutterButton(page, 'Importar');
    await expect(flutterText(page, 'Importar aviones')).toBeVisible();
    await expect(flutterText(page, /HC-ABC · Airbus A320/)).toBeVisible();

    // Vuelve a Administración mediante las migas táctiles y abre Gestionar vuelos
    await clickFlutterButton(page, /Ir a Administración/);
    await clickFlutterButton(page, 'Gestionar');

    await expect(flutterText(page, 'Gestionar vuelos')).toBeVisible();
    await expect(flutterText(page, 'KT101')).toBeVisible();

    // Intenta cancelar KT101: primer intento recibe 409 de versión optimista; segundo intento confirma
    await clickFlutterButton(page, 'Cancelar vuelo');
    await expect(flutterText(page, /¿Cancelar el vuelo KT101\?/)).toBeVisible();
    await fillFlutterField(page, /Motivo de la cancelación/, 'Cierre temporal por mantenimiento de pista');
    await clickFlutterButton(page, 'Cancelar vuelo', { last: true });

    // Aviso de conflicto de versión optimista 409
    await expect(flutterText(page, /Otro administrador cambió este vuelo/)).toBeVisible();

    // Reintenta con la versión actualizada
    await clickFlutterButton(page, 'Cancelar vuelo', { last: true });
    await expect(flutterText(page, 'Cancelado')).toBeVisible();

    expect(getErrors()).toEqual([]);
  });
});
