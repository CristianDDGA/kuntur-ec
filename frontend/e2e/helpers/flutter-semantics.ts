import { expect, type Locator, type Page } from '@playwright/test';

/**
 * Abre una ruta de Kuntur EC (Flutter Web con hash routing) y espera a que el árbol
 * de semántica (`flt-semantics-host`) quede hidratado y listo para locators ARIA.
 */
export async function gotoKuntur(page: Page, hashPath = '/'): Promise<void> {
  const normalized = hashPath.startsWith('/') ? hashPath : `/${hashPath}`;
  await page.goto(`/#${normalized}`, { waitUntil: 'domcontentloaded' });
  await waitForFlutterReady(page);
}

/**
 * Garantiza que Flutter Web montó el canvas y activó el árbol de accesibilidad.
 * Si el build no activó `ENABLE_SEMANTICS=true`, dispara el placeholder oficial de Flutter.
 */
export async function waitForFlutterReady(page: Page): Promise<void> {
  await page.waitForSelector('flutter-view, flt-glass-pane', { timeout: 25_000 });

  const semanticsReady = await page
    .waitForSelector('flt-semantics-host flt-semantics', { state: 'attached', timeout: 8_000 })
    .then(() => true)
    .catch(() => false);

  if (!semanticsReady) {
    const placeholder = page.locator('flt-semantics-placeholder').first();
    if (await placeholder.count()) {
      await placeholder.dispatchEvent('click');
    }
    await page.waitForSelector('flt-semantics-host flt-semantics', { state: 'attached', timeout: 15_000 });
  }
}

/**
 * Escribe texto en un campo `TextFormField` de Flutter Web de forma confiable.
 * En CanvasKit, el `<input>` oculto conecta su `TextInputConnection` un frame después del click;
 * esperar el foco y despachar pulsaciones secuenciales garantiza sincronización con Dart.
 */
export async function fillFlutterField(page: Page, label: string | RegExp, value: string): Promise<void> {
  const field = page.getByRole('textbox', { name: label }).first();
  await expect(field).toBeVisible();
  await field.click();
  await page.waitForTimeout(120);
  await page.keyboard.press('ControlOrMeta+A');
  await page.keyboard.press('Backspace');
  await page.keyboard.type(value, { delay: 12 });
  await page.waitForTimeout(60);
}

/**
 * Hace clic en un control semántico (botón o pestaña de NavigationBar) asegurando visibilidad previa.
 */
export async function clickFlutterButton(
  page: Page,
  name: string | RegExp,
  options?: { exact?: boolean; last?: boolean },
): Promise<void> {
  const exact = options?.exact ?? false;
  const candidates = page
    .getByRole('button', { name, exact })
    .or(page.getByRole('tab', { name, exact }));
  const button = options?.last ? candidates.last() : candidates.first();
  await expect(button).toBeVisible();
  await button.click();
}

/**
 * Busca texto dentro del árbol semántico de Flutter Web tanto en `textContent`
 * como en `aria-label` (grupos, progressbars y botones compuestos en CanvasKit).
 */
export function flutterText(page: Page, text: string | RegExp): Locator {
  if (typeof text === 'string') {
    const escaped = text.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
    return page.getByText(text).or(page.locator(`[aria-label*="${escaped}"]`)).first();
  }
  return page
    .getByText(text)
    .or(page.getByRole('group', { name: text }))
    .or(page.getByRole('progressbar', { name: text }))
    .or(page.getByRole('button', { name: text }))
    .first();
}

/**
 * Registra errores de consola / excepciones no capturadas en la página para
 * validar cero errores de runtime al final del test.
 * `allowHttpStatuses` permite ignorar únicamente errores HTTP simulados a propósito (p. ej. 409).
 */
export function attachConsoleGuard(page: Page, options?: { allowHttpStatuses?: number[] }): () => string[] {
  const errors: string[] = [];
  const allowedStatuses = options?.allowHttpStatuses ?? [];
  page.on('pageerror', (err) => errors.push(`pageerror: ${err.message}`));
  page.on('console', (msg) => {
    if (msg.type() === 'error') {
      const text = msg.text();
      const isAllowedStatus = allowedStatuses.some((code) => text.includes(`status of ${code}`));
      // Ignora avisos esperados de recursos externos en modo offline/mock o códigos HTTP probados
      if (!text.includes('favicon') && !text.includes('fonts.gstatic.com') && !isAllowedStatus) {
        errors.push(`console.error: ${text}`);
      }
    }
  });
  return () => errors;
}

/**
 * Verifica que el documento no presente desbordamiento horizontal.
 */
export async function expectNoHorizontalOverflow(page: Page): Promise<void> {
  const overflow = await page.evaluate(() => {
    return document.documentElement.scrollWidth - document.documentElement.clientWidth;
  });
  expect(overflow).toBeLessThanOrEqual(2);
}
