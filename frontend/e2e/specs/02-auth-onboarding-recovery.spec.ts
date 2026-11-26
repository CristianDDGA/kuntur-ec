import { expect, test } from '@playwright/test';

import { installSoaMock } from '../fixtures/soa-mock';
import {
  attachConsoleGuard,
  clickFlutterButton,
  fillFlutterField,
  flutterText,
  gotoKuntur,
} from '../helpers/flutter-semantics';

test.describe('02 · Autenticación, registro con OTP, recuperación de clave y completar cédula', () => {
  test('registro completo -> verificación OTP 6 dígitos -> ingreso al catálogo', async ({ page }) => {
    const getErrors = attachConsoleGuard(page);
    await installSoaMock(page);

    await gotoKuntur(page, '/registro');
    await expect(flutterText(page, 'Cree su cuenta')).toBeVisible();

    await fillFlutterField(page, /Nombre completo/, 'Carlos Mendoza');
    await fillFlutterField(page, /Cédula de identidad/, '1710034065');
    await fillFlutterField(page, /Correo electrónico/, 'carlos.mendoza@correo.com');
    await fillFlutterField(page, /^Contraseña$/, 'ClaveSegura1');
    await fillFlutterField(page, /Repita la contraseña/, 'ClaveSegura1');

    await clickFlutterButton(page, 'Crear cuenta');

    // Paso de verificación OTP
    await expect(flutterText(page, 'Confirme su correo')).toBeVisible();
    await fillFlutterField(page, /Código de verificación/, '123456');
    await clickFlutterButton(page, 'Verificar');

    // Ingreso automático al catálogo de vuelos
    await expect(flutterText(page, 'Hola, Carlos')).toBeVisible();
    await expect(flutterText(page, 'KT101')).toBeVisible();

    expect(getErrors()).toEqual([]);
  });

  test('recuperación de contraseña en 2 pasos muestra confirmación en login', async ({ page }) => {
    const getErrors = attachConsoleGuard(page);
    await installSoaMock(page);

    await gotoKuntur(page, '/login');
    await clickFlutterButton(page, '¿Olvidó su contraseña?');

    await expect(flutterText(page, 'Recupere su contraseña')).toBeVisible();
    await expect(page.getByRole('button', { name: 'Iniciar sesión', exact: true })).toBeHidden();
    await expect(page.getByRole('button', { name: 'Enviar código' })).toBeVisible();
    await fillFlutterField(page, /Correo electrónico/, 'ana@correo.com');
    await clickFlutterButton(page, 'Enviar código');

    await expect(flutterText(page, 'Cree una contraseña nueva')).toBeVisible();
    await fillFlutterField(page, /Código de verificación/, '654321');
    await fillFlutterField(page, /Contraseña nueva/, 'NuevaClave99');
    await fillFlutterField(page, /Repita la contraseña/, 'NuevaClave99');
    await clickFlutterButton(page, 'Cambiar contraseña');

    // Vuelve al login con banner de confirmación
    await expect(flutterText(page, 'Bienvenido de vuelta')).toBeVisible();
    await expect(flutterText(page, /Contraseña actualizada/)).toBeVisible();

    expect(getErrors()).toEqual([]);
  });

  test('cliente sin cédula completa su perfil sin botón de bucle y entra al catálogo', async ({ page }) => {
    const getErrors = attachConsoleGuard(page);
    await installSoaMock(page, { clienteSinCedula: true });

    await gotoKuntur(page, '/login');
    await fillFlutterField(page, /Correo electrónico/, 'ana@correo.com');
    await fillFlutterField(page, /Contraseña/, 'Clave1234');
    await clickFlutterButton(page, 'Iniciar sesión');

    await expect(flutterText(page, 'Complete su perfil')).toBeVisible();
    // "Volver al inicio" no debe existir en CompletarCedulaPage (previene bucle de redirección)
    await expect(page.getByRole('button', { name: /Volver al inicio/ })).toHaveCount(0);

    await fillFlutterField(page, /Cédula de identidad/, '1710034065');
    await clickFlutterButton(page, 'Guardar y continuar');

    await expect(flutterText(page, 'Hola, Ana')).toBeVisible();
    expect(getErrors()).toEqual([]);
  });
});
