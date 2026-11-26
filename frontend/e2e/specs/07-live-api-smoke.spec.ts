import { expect, test } from '@playwright/test';

import { attachConsoleGuard, flutterText, gotoKuntur } from '../helpers/flutter-semantics';

const LIVE_ENABLED = process.env.PLAYWRIGHT_LIVE_API === '1';

test.describe('07 · Smoke test opcional de solo lectura contra API SOA real', () => {
  test.skip(!LIVE_ENABLED, 'Desactivado por defecto; ejecutar con PLAYWRIGHT_LIVE_API=1 para smoke read-only.');

  test('consulta /estado y portada pública contra la API real sin mutar Supabase', async ({ page }) => {
    const getErrors = attachConsoleGuard(page);

    await gotoKuntur(page, '/estado');
    await expect(flutterText(page, 'Estado del servicio')).toBeVisible();
    await expect(flutterText(page, /API conectada/)).toBeVisible({ timeout: 25_000 });

    await gotoKuntur(page, '/');
    await expect(flutterText(page, 'Descubre las 4 regiones del Ecuador')).toBeVisible();
    await expect(flutterText(page, 'Destinos populares del Ecuador')).toBeVisible();

    expect(getErrors()).toEqual([]);
  });
});
