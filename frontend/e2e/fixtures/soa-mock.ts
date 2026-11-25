import type { Page, Route } from '@playwright/test';

export interface MockUser {
  id: number;
  nombre: string;
  correo: string;
  rol: 'cliente' | 'admin';
  fecha_registro: string;
  cedula: string | null;
}

export interface MockFlight {
  id: number;
  codigo: string;
  origen: string;
  destino: string;
  fecha: string;
  hora_salida: string;
  hora_llegada: string;
  precio: string;
  capacidad: number;
  asientos_disponibles: number;
  version: number;
  avion_id: number;
  estado: 'programado' | 'cancelado';
  motivo_cancelacion: string | null;
  ya_partio: boolean;
  ocupados: string[];
}

export interface MockReservation {
  id: number;
  usuario_id: number;
  vuelo_id: number;
  asientos: string[];
  subtotal: string;
  iva_porcentaje: string;
  iva_valor: string;
  total: string;
  estado: 'confirmada' | 'cancelada';
  fecha_reserva: string;
  version: number;
}

export interface SoaMockOptions {
  /** Si se indica, simula conflicto 409 en la próxima creación/modificación de reserva con estos asientos ocupados. */
  conflictSeatsOnce?: string[];
  /** Si es true, la próxima edición/cancelación de vuelo devuelve 409 con version_actual + 1. */
  conflictFlightVersionOnce?: boolean;
  /** Si es true, inyecta datos extremos (break-ui: nombres largos, correos largos, precios altos). */
  worstCaseData?: boolean;
  /** TTL del JWT generado en segundos (útil para probar vencimiento de sesión). */
  tokenTtlSeconds?: number;
  /** Usuario cliente sin cédula para probar flujo CompletarCedulaPage. */
  clienteSinCedula?: boolean;
}

function makeJwt(sub: string, ttlSeconds: number): string {
  const b64 = (obj: Record<string, unknown>) =>
    Buffer.from(JSON.stringify(obj), 'utf8').toString('base64url');
  const exp = Math.floor(Date.now() / 1000) + ttlSeconds;
  return `${b64({ alg: 'HS256', typ: 'JWT' })}.${b64({ sub, exp })}.firma-e2e`;
}

function centsToStr(cents: number): string {
  const abs = Math.abs(cents);
  const whole = Math.floor(abs / 100);
  const dec = String(abs % 100).padStart(2, '0');
  return `${cents < 0 ? '-' : ''}${whole}.${dec}`;
}

function strToCents(val: string): number {
  const [w, d = '00'] = val.split('.');
  return Number(w) * 100 + Number(d.padEnd(2, '0').slice(0, 2));
}

function corsHeaders(contentType = 'application/json; charset=utf-8'): Record<string, string> {
  return {
    'Content-Type': contentType,
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type, Accept',
  };
}

export class SoaMockController {
  public flights: MockFlight[];
  public reservations: MockReservation[];
  public planes: Array<{ id: number; matricula: string; modelo: string; filas: number; capacidad: number }>;
  public ivaRates: Array<{ id: number; porcentaje: string; vigente_desde: string; vigente_hasta: string | null; estado: string }>;
  public activeUser: MockUser | null = null;
  public lastResetEmail: string | null = null;
  public pendingVerificationUser: MockUser | null = null;
  private conflictSeatsOnce?: string[];
  private conflictFlightVersionOnce: boolean;
  private tokenTtlSeconds: number;
  private clienteSinCedula: boolean;
  private nextFlightId = 10;
  private nextReservationId = 59;
  private nextPlaneId = 8;
  private nextIvaId = 3;

  constructor(options: SoaMockOptions = {}) {
    this.conflictSeatsOnce = options.conflictSeatsOnce ? [...options.conflictSeatsOnce] : undefined;
    this.conflictFlightVersionOnce = Boolean(options.conflictFlightVersionOnce);
    this.tokenTtlSeconds = options.tokenTtlSeconds ?? 7200;
    this.clienteSinCedula = Boolean(options.clienteSinCedula);

    this.planes = [
      { id: 7, matricula: 'HC-ABC', modelo: 'Airbus A320', filas: 6, capacidad: 24 },
      { id: 8, matricula: 'HC-KTR', modelo: 'Embraer 190', filas: 5, capacidad: 20 },
    ];

    this.ivaRates = [
      { id: 2, porcentaje: '15.00', vigente_desde: '2024-04-01', vigente_hasta: null, estado: 'vigente' },
      { id: 1, porcentaje: '12.00', vigente_desde: '2000-01-01', vigente_hasta: '2024-04-01', estado: 'anterior' },
    ];

    if (options.worstCaseData) {
      this.flights = [
        {
          id: 3,
          codigo: 'KT901',
          origen: 'San Francisco de Quito Distrito Metropolitano Sur',
          destino: 'Puerto Baquerizo Moreno Isla San Cristóbal Galápagos',
          fecha: '2030-12-01',
          hora_salida: '08:00:00',
          hora_llegada: '10:45:00',
          precio: '2240.00',
          capacidad: 24,
          asientos_disponibles: 22,
          version: 1,
          avion_id: 7,
          estado: 'programado',
          motivo_cancelacion: null,
          ya_partio: false,
          ocupados: ['1A', '1B'],
        },
      ];
    } else {
      this.flights = [
        {
          id: 3,
          codigo: 'KT101',
          origen: 'Quito',
          destino: 'Guayaquil',
          fecha: '2030-12-01',
          hora_salida: '08:00:00',
          hora_llegada: '08:55:00',
          precio: '75.50',
          capacidad: 24,
          asientos_disponibles: 22,
          version: 1,
          avion_id: 7,
          estado: 'programado',
          motivo_cancelacion: null,
          ya_partio: false,
          ocupados: ['1A', '1B'],
        },
        {
          id: 4,
          codigo: 'KT202',
          origen: 'Cuenca',
          destino: 'Quito',
          fecha: '2030-12-02',
          hora_salida: '14:30:00',
          hora_llegada: '15:25:00',
          precio: '60.00',
          capacidad: 20,
          asientos_disponibles: 4,
          version: 2,
          avion_id: 8,
          estado: 'programado',
          motivo_cancelacion: null,
          ya_partio: false,
          ocupados: ['1A'],
        },
      ];
    }

    this.reservations = [
      {
        id: 58,
        usuario_id: 7,
        vuelo_id: 3,
        asientos: ['1A', '1B'],
        subtotal: options.worstCaseData ? '22400.00' : '151.00',
        iva_porcentaje: '15.00',
        iva_valor: options.worstCaseData ? '3360.00' : '22.65',
        total: options.worstCaseData ? '25760.00' : '173.65',
        estado: 'confirmada',
        fecha_reserva: '2026-11-11T15:00:00+00:00',
        version: 1,
      },
    ];
  }

  private getClientUser(): MockUser {
    return {
      id: 7,
      nombre: this.flights[0]?.codigo === 'KT901'
        ? 'Aleksandra Wiśniewska-Kowalczyk de los Ángeles Montalvo Rivadeneira'
        : 'Ana Torres',
      correo: this.flights[0]?.codigo === 'KT901'
        ? 'aleksandra.wisniewska.kowalczyk@northwind-industries-holdings.example.com'
        : 'ana@correo.com',
      rol: 'cliente',
      fecha_registro: '2026-11-10T15:04:04+00:00',
      cedula: this.clienteSinCedula ? null : '1710034065',
    };
  }

  private getAdminUser(): MockUser {
    return {
      id: 1,
      nombre: 'Administrador Kuntur',
      correo: 'admin@kuntur.ec',
      rol: 'admin',
      fecha_registro: '2026-11-01T10:00:00+00:00',
      cedula: null,
    };
  }

  private serializeReservation(r: MockReservation) {
    const f = this.flights.find((fl) => fl.id === r.vuelo_id) ?? this.flights[0];
    return {
      id: r.id,
      usuario_id: r.usuario_id,
      vuelo_id: r.vuelo_id,
      cantidad_asientos: r.asientos.length,
      subtotal: r.subtotal,
      iva_porcentaje: r.iva_porcentaje,
      iva_valor: r.iva_valor,
      total: r.total,
      estado: r.estado,
      fecha_reserva: r.fecha_reserva,
      version: r.version,
      asientos: r.asientos,
      vuelo: {
        codigo: f.codigo,
        origen: f.origen,
        destino: f.destino,
        fecha: f.fecha,
        hora_salida: f.hora_salida,
        hora_llegada: f.hora_llegada,
        estado: f.estado,
        motivo_cancelacion: f.motivo_cancelacion,
      },
    };
  }

  private buildInvoiceXml(r: MockReservation): string {
    const f = this.flights.find((fl) => fl.id === r.vuelo_id) ?? this.flights[0];
    const u = this.activeUser ?? this.getClientUser();
    const num = `KEC-${String(r.id).padStart(8, '0')}`;
    const unitario = centsToStr(Math.round(strToCents(r.subtotal) / Math.max(1, r.asientos.length)));
    const estado = r.estado === 'cancelada' ? 'Anulada' : 'Confirmada';
    return `<?xml version="1.0" encoding="utf-8"?>
<factura>
  <cabecera>
    <numero>${num}</numero>
    <fecha>2026-11-11</fecha>
  </cabecera>
  <cliente>
    <nombre>${u.nombre}</nombre>
    <correo>${u.correo}</correo>
  </cliente>
  <Detalle>
    <producto>
      <Nombre>Pasaje ${f.codigo} ${f.origen} - ${f.destino} (${f.fecha} ${f.hora_salida.slice(0, 5)})</Nombre>
      <Asientos>${r.asientos.join(', ')}</Asientos>
      <Cantidad>${r.asientos.length}</Cantidad>
      <PrecioUnitario>${unitario}</PrecioUnitario>
      <Subtotal>${r.subtotal}</Subtotal>
    </producto>
  </Detalle>
  <Totales>
    <Subtotal>${r.subtotal}</Subtotal>
    <PorcentajeIVA>${r.iva_porcentaje}</PorcentajeIVA>
    <IVA>${r.iva_valor}</IVA>
    <Total>${r.total}</Total>
  </Totales>
  <Estado>${estado}</Estado>
</factura>`;
  }

  public async attach(page: Page): Promise<void> {
    await page.route('**/api/**', async (route: Route) => {
      const req = route.request();
      const method = req.method();
      if (method === 'OPTIONS') {
        await route.fulfill({ status: 204, headers: corsHeaders() });
        return;
      }

      const url = new URL(req.url());
      const apiIdx = url.pathname.indexOf('/api');
      const path = apiIdx >= 0 ? url.pathname.slice(apiIdx + 4) : url.pathname;

      const json = async (status: number, body: unknown) => {
        await route.fulfill({ status, headers: corsHeaders(), body: JSON.stringify(body) });
      };

      const parseBody = (): Record<string, unknown> => {
        try {
          return JSON.parse(req.postData() ?? '{}');
        } catch {
          return {};
        }
      };

      // 1. Health & Destinos públicos
      if (method === 'GET' && path === '/health') {
        return json(200, { estado: 'ok', servicio: 'kuntur-ec-api', hora: new Date().toISOString() });
      }
      if (method === 'GET' && path === '/vuelos/destinos') {
        return json(200, {
          destinos: [
            { destino: 'Guayaquil', precio_minimo: '75.50', vuelos: 3 },
            { destino: 'Quito', precio_minimo: '60.00', vuelos: 4 },
            { destino: 'Cuenca', precio_minimo: '68.00', vuelos: 2 },
            { destino: 'Galápagos', precio_minimo: '145.00', vuelos: 1 },
          ],
        });
      }

      // 2. Auth & Usuarios
      if (method === 'POST' && path === '/auth/login') {
        const body = parseBody();
        const correo = String(body.correo ?? '').toLowerCase();
        const password = String(body.password ?? '');
        if (password === 'wrong123') {
          return json(401, { error: 'credenciales', mensaje: 'Correo o contraseña incorrectos.' });
        }
        const user = correo.includes('admin')
          ? this.getAdminUser()
          : this.pendingVerificationUser && correo === this.pendingVerificationUser.correo.toLowerCase()
            ? this.pendingVerificationUser
            : this.getClientUser();
        this.activeUser = user;
        return json(200, {
          token: makeJwt(String(user.id), this.tokenTtlSeconds),
          tipo: 'Bearer',
          expira: new Date(Date.now() + this.tokenTtlSeconds * 1000).toISOString(),
          usuario: user,
        });
      }

      if (method === 'GET' && path === '/auth/perfil') {
        if (!this.activeUser) {
          const auth = req.headers()['authorization'] ?? '';
          if (!auth.startsWith('Bearer ')) {
            return json(401, { error: 'no_autorizado', mensaje: 'Token inválido.' });
          }
          this.activeUser = this.getClientUser();
        }
        return json(200, { usuario: this.activeUser });
      }

      if (method === 'POST' && path === '/auth/logout') {
        this.activeUser = null;
        return json(200, { mensaje: 'Sesión cerrada.' });
      }

      if (method === 'POST' && path === '/usuarios/registro') {
        const body = parseBody();
        this.pendingVerificationUser = {
          id: 99,
          nombre: String(body.nombre ?? 'Nuevo Usuario'),
          correo: String(body.correo ?? 'nuevo@correo.com'),
          rol: 'cliente',
          fecha_registro: new Date().toISOString(),
          cedula: String(body.cedula ?? '1710034065'),
        };
        return json(201, {
          mensaje: 'Cuenta creada. Revise su correo.',
          verificacion_requerida: true,
          correo_enviado: true,
          usuario: this.pendingVerificationUser,
        });
      }

      if (method === 'POST' && path === '/auth/verificar-correo') {
        const body = parseBody();
        if (String(body.codigo) !== '123456') {
          return json(400, { error: 'codigo_invalido', mensaje: 'Código incorrecto o vencido.' });
        }
        const user = this.pendingVerificationUser ?? this.getClientUser();
        this.activeUser = user;
        return json(200, {
          token: makeJwt(String(user.id), this.tokenTtlSeconds),
          tipo: 'Bearer',
          expira: new Date(Date.now() + this.tokenTtlSeconds * 1000).toISOString(),
          usuario: user,
        });
      }

      if (method === 'POST' && path === '/auth/reenviar-codigo') {
        return json(200, { mensaje: 'Código reenviado.' });
      }

      if (method === 'POST' && path === '/auth/recuperar-clave') {
        const body = parseBody();
        this.lastResetEmail = String(body.correo ?? '');
        return json(200, { mensaje: 'Si el correo existe, se envió el código.' });
      }

      if (method === 'POST' && path === '/auth/restablecer-clave') {
        const body = parseBody();
        if (String(body.codigo) !== '654321') {
          return json(400, { error: 'codigo_invalido', mensaje: 'El código de recuperación no es válido.' });
        }
        return json(200, { mensaje: 'Contraseña restablecida correctamente.' });
      }

      if (method === 'PUT' && path === '/usuarios/cedula') {
        const body = parseBody();
        if (this.activeUser) {
          this.activeUser = {
            ...this.activeUser,
            cedula: String(body.cedula ?? '1710034065'),
            nombre: body.nombre ? String(body.nombre) : this.activeUser.nombre,
          };
        }
        this.clienteSinCedula = false;
        return json(200, { usuario: this.activeUser });
      }

      // 3. Vuelos
      if (method === 'GET' && path === '/vuelos') {
        const origen = (url.searchParams.get('origen') ?? '').toLowerCase();
        const destino = (url.searchParams.get('destino') ?? '').toLowerCase();
        const filtrados = this.flights.filter((f) => {
          if (f.estado === 'cancelado') return false;
          if (origen && !f.origen.toLowerCase().includes(origen)) return false;
          if (destino && !f.destino.toLowerCase().includes(destino)) return false;
          return true;
        });
        return json(200, {
          total: filtrados.length,
          pagina: 1,
          por_pagina: 10,
          total_paginas: 1,
          vuelos: filtrados,
        });
      }

      if (method === 'GET' && path === '/vuelos/gestion') {
        const estado = url.searchParams.get('estado');
        const filtrados = this.flights.filter((f) => !estado || f.estado === estado);
        return json(200, {
          total: filtrados.length,
          pagina: 1,
          por_pagina: 10,
          total_paginas: 1,
          vuelos: filtrados.map((f) => ({
            ...f,
            asientos_vendidos: f.capacidad - f.asientos_disponibles,
          })),
        });
      }

      const flightSeatsMatch = path.match(/^\/vuelos\/(\d+)\/asientos$/);
      if (method === 'GET' && flightSeatsMatch) {
        const id = Number(flightSeatsMatch[1]);
        const f = this.flights.find((fl) => fl.id === id);
        if (!f) return json(404, { error: 'no_encontrado', mensaje: 'Vuelo no encontrado.' });
        return json(200, {
          vuelo_id: f.id,
          capacidad: f.capacidad,
          columnas: ['A', 'B', 'C', 'D'],
          ocupados: f.ocupados,
        });
      }

      const flightCancelMatch = path.match(/^\/vuelos\/(\d+)\/cancelacion$/);
      if (method === 'POST' && flightCancelMatch) {
        const id = Number(flightCancelMatch[1]);
        const f = this.flights.find((fl) => fl.id === id);
        if (!f) return json(404, { error: 'no_encontrado', mensaje: 'Vuelo no encontrado.' });
        if (this.conflictFlightVersionOnce) {
          this.conflictFlightVersionOnce = false;
          f.version += 1;
          return json(409, {
            error: 'conflicto',
            mensaje: 'El vuelo fue modificado por otro administrador.',
            version_actual: f.version,
          });
        }
        const body = parseBody();
        f.estado = 'cancelado';
        f.motivo_cancelacion = String(body.motivo ?? 'Cancelado por pruebas');
        let canceladas = 0;
        for (const r of this.reservations) {
          if (r.vuelo_id === f.id && r.estado === 'confirmada') {
            r.estado = 'cancelada';
            canceladas++;
          }
        }
        return json(200, { vuelo: f, reservas_canceladas: canceladas });
      }

      const flightMatch = path.match(/^\/vuelos\/(\d+)$/);
      if (flightMatch && method === 'GET') {
        const id = Number(flightMatch[1]);
        const f = this.flights.find((fl) => fl.id === id);
        if (!f) return json(404, { error: 'no_encontrado', mensaje: 'Vuelo no encontrado.' });
        return json(200, f);
      }

      if (flightMatch && method === 'PUT') {
        const id = Number(flightMatch[1]);
        const f = this.flights.find((fl) => fl.id === id);
        if (!f) return json(404, { error: 'no_encontrado', mensaje: 'Vuelo no encontrado.' });
        if (this.conflictFlightVersionOnce) {
          this.conflictFlightVersionOnce = false;
          f.version += 1;
          return json(409, {
            error: 'conflicto',
            mensaje: 'Otro administrador actualizó este vuelo antes.',
            version_actual: f.version,
          });
        }
        const body = parseBody();
        f.origen = String(body.origen ?? f.origen);
        f.destino = String(body.destino ?? f.destino);
        f.fecha = String(body.fecha ?? f.fecha);
        f.hora_salida = `${String(body.hora_salida ?? '08:00')}:00`.slice(0, 8);
        f.hora_llegada = `${String(body.hora_llegada ?? '09:00')}:00`.slice(0, 8);
        f.precio = String(body.precio ?? f.precio);
        f.version += 1;
        return json(200, { vuelo: f });
      }

      if (method === 'POST' && path === '/vuelos') {
        const body = parseBody();
        const plane = this.planes.find((p) => p.id === Number(body.avion_id)) ?? this.planes[0];
        const nuevo: MockFlight = {
          id: ++this.nextFlightId,
          codigo: `KT${300 + this.nextFlightId}`,
          origen: String(body.origen),
          destino: String(body.destino),
          fecha: String(body.fecha),
          hora_salida: `${String(body.hora_salida)}:00`.slice(0, 8),
          hora_llegada: `${String(body.hora_llegada)}:00`.slice(0, 8),
          precio: String(body.precio),
          capacidad: plane.capacidad,
          asientos_disponibles: plane.capacidad,
          version: 1,
          avion_id: plane.id,
          estado: 'programado',
          motivo_cancelacion: null,
          ya_partio: false,
          ocupados: [],
        };
        this.flights.unshift(nuevo);
        return json(201, { vuelo: nuevo });
      }

      // 4. Reservas & Comprobante XML
      if (method === 'GET' && path === '/reservas/resumen') {
        const confirmadas = this.reservations.filter((r) => r.estado === 'confirmada');
        const canceladas = this.reservations.filter((r) => r.estado === 'cancelada');
        const subtotalCent = confirmadas.reduce((a, r) => a + strToCents(r.subtotal), 0);
        const totalCent = confirmadas.reduce((a, r) => a + strToCents(r.total), 0);
        const ivaCent = confirmadas.reduce((a, r) => a + strToCents(r.iva_valor), 0);
        const asientosVendidos = confirmadas.reduce((a, r) => a + r.asientos.length, 0);
        return json(200, {
          reservas_confirmadas: confirmadas.length,
          reservas_canceladas: canceladas.length,
          asientos_vendidos: asientosVendidos,
          subtotal: centsToStr(subtotalCent),
          iva: centsToStr(ivaCent),
          total: centsToStr(totalCent),
          vuelos_top: [
            {
              codigo: 'KT101',
              origen: 'Quito',
              destino: 'Guayaquil',
              asientos: asientosVendidos,
              total: centsToStr(totalCent),
            },
          ],
        });
      }

      if (method === 'GET' && path === '/reservas') {
        return json(200, {
          total: this.reservations.length,
          pagina: 1,
          por_pagina: 10,
          total_paginas: 1,
          reservas: this.reservations.map((r) => this.serializeReservation(r)),
        });
      }

      if (method === 'POST' && path === '/reservas') {
        const body = parseBody();
        const vueloId = Number(body.vuelo_id);
        const asientos = (body.asientos as string[]) ?? [];
        const f = this.flights.find((fl) => fl.id === vueloId) ?? this.flights[0];
        if (this.conflictSeatsOnce && this.conflictSeatsOnce.length > 0) {
          const ocupados = this.conflictSeatsOnce;
          this.conflictSeatsOnce = undefined;
          for (const a of ocupados) {
            if (!f.ocupados.includes(a)) f.ocupados.push(a);
          }
          return json(409, {
            error: 'asientos_ocupados',
            mensaje: `Los asientos ${ocupados.join(', ')} ya fueron reservados por otro pasajero.`,
            asientos_ocupados: ocupados,
          });
        }
        const unit = strToCents(f.precio);
        const sub = unit * asientos.length;
        const iva = Math.floor((sub * 1500 + 5000) / 10000);
        const nueva: MockReservation = {
          id: ++this.nextReservationId,
          usuario_id: this.activeUser?.id ?? 7,
          vuelo_id: f.id,
          asientos,
          subtotal: centsToStr(sub),
          iva_porcentaje: '15.00',
          iva_valor: centsToStr(iva),
          total: centsToStr(sub + iva),
          estado: 'confirmada',
          fecha_reserva: new Date().toISOString(),
          version: 1,
        };
        this.reservations.unshift(nueva);
        f.ocupados = Array.from(new Set([...f.ocupados, ...asientos]));
        f.asientos_disponibles = Math.max(0, f.capacidad - f.ocupados.length);
        return json(201, { reserva: this.serializeReservation(nueva) });
      }

      const xmlMatch = path.match(/^\/reservas\/(\d+)\/comprobante$/);
      if (method === 'GET' && xmlMatch) {
        const id = Number(xmlMatch[1]);
        const r = this.reservations.find((res) => res.id === id);
        if (!r) return json(404, { error: 'no_encontrado', mensaje: 'Comprobante no encontrado.' });
        await route.fulfill({
          status: 200,
          headers: corsHeaders('application/xml; charset=utf-8'),
          body: this.buildInvoiceXml(r),
        });
        return;
      }

      const resMatch = path.match(/^\/reservas\/(\d+)$/);
      if (resMatch && method === 'GET') {
        const id = Number(resMatch[1]);
        const r = this.reservations.find((res) => res.id === id);
        if (!r) return json(404, { error: 'no_encontrado', mensaje: 'Reserva no encontrada.' });
        return json(200, this.serializeReservation(r));
      }

      if (resMatch && method === 'PUT') {
        const id = Number(resMatch[1]);
        const r = this.reservations.find((res) => res.id === id);
        if (!r) return json(404, { error: 'no_encontrado', mensaje: 'Reserva no encontrada.' });
        const f = this.flights.find((fl) => fl.id === r.vuelo_id) ?? this.flights[0];
        if (this.conflictSeatsOnce && this.conflictSeatsOnce.length > 0) {
          const ocupados = this.conflictSeatsOnce;
          this.conflictSeatsOnce = undefined;
          for (const a of ocupados) {
            if (!f.ocupados.includes(a)) f.ocupados.push(a);
          }
          return json(409, {
            error: 'asientos_ocupados',
            mensaje: `Los asientos ${ocupados.join(', ')} ya fueron ocupados.`,
            asientos_ocupados: ocupados,
          });
        }
        const body = parseBody();
        const nuevos = (body.asientos as string[]) ?? r.asientos;
        f.ocupados = f.ocupados.filter((a) => !r.asientos.includes(a));
        f.ocupados = Array.from(new Set([...f.ocupados, ...nuevos]));
        r.asientos = nuevos;
        const unit = strToCents(f.precio);
        const sub = unit * nuevos.length;
        const iva = Math.floor((sub * 1500 + 5000) / 10000);
        r.subtotal = centsToStr(sub);
        r.iva_valor = centsToStr(iva);
        r.total = centsToStr(sub + iva);
        r.version += 1;
        return json(200, { reserva: this.serializeReservation(r) });
      }

      if (resMatch && method === 'DELETE') {
        const id = Number(resMatch[1]);
        const r = this.reservations.find((res) => res.id === id);
        if (!r) return json(404, { error: 'no_encontrado', mensaje: 'Reserva no encontrada.' });
        const f = this.flights.find((fl) => fl.id === r.vuelo_id);
        if (f) {
          f.ocupados = f.ocupados.filter((a) => !r.asientos.includes(a));
          f.asientos_disponibles = Math.min(f.capacidad, f.capacidad - f.ocupados.length);
        }
        r.estado = 'cancelada';
        r.version += 1;
        return json(200, { reserva: this.serializeReservation(r) });
      }

      // 5. IVA
      if (method === 'GET' && path === '/iva') {
        const vigente = this.ivaRates.find((t) => t.estado === 'vigente') ?? null;
        return json(200, { vigente, tarifas: this.ivaRates });
      }
      if (method === 'POST' && path === '/iva') {
        const body = parseBody();
        const nueva = {
          id: ++this.nextIvaId,
          porcentaje: Number(body.porcentaje).toFixed(2),
          vigente_desde: String(body.vigente_desde),
          vigente_hasta: null,
          estado: 'programada',
        };
        this.ivaRates.unshift(nueva);
        return json(201, { tarifa: nueva });
      }

      // 6. Aviones & CSV
      if (method === 'GET' && path === '/aviones') {
        return json(200, { total: this.planes.length, aviones: this.planes });
      }
      if (method === 'POST' && path === '/aviones/importacion/validar') {
        const csv = req.postData() ?? '';
        const lines = csv.trim().split(/\r?\n/);
        const errores: Array<{ linea: number; mensaje: string }> = [];
        const vista_previa: Array<{ matricula: string; modelo: string; filas: number; capacidad: number; ya_existe: boolean }> = [];
        const existentes: string[] = [];
        let nuevos = 0;

        for (let i = 1; i < lines.length; i++) {
          const [matricula = '', modelo = '', filasRaw = ''] = lines[i].split(';').map((s) => s.trim());
          const filas = Number(filasRaw);
          if (!matricula || !modelo || !Number.isInteger(filas) || filas < 1 || filas > 50) {
            errores.push({ linea: i + 1, mensaje: 'Fila CSV inválida: verifique matricula;modelo;filas (1-50).' });
            continue;
          }
          const ya_existe = this.planes.some((p) => p.matricula === matricula);
          if (ya_existe) existentes.push(matricula);
          else nuevos++;
          vista_previa.push({ matricula, modelo, filas, capacidad: filas * 4, ya_existe });
        }
        return json(200, {
          valido: errores.length === 0,
          nuevos,
          existentes,
          errores,
          vista_previa,
        });
      }
      if (method === 'POST' && path === '/aviones/importacion') {
        const csv = req.postData() ?? '';
        const lines = csv.trim().split(/\r?\n/).slice(1);
        let creados = 0;
        const omitidos: string[] = [];
        for (const line of lines) {
          const [matricula = '', modelo = '', filasRaw = ''] = line.split(';').map((s) => s.trim());
          const filas = Number(filasRaw);
          if (this.planes.some((p) => p.matricula === matricula)) {
            omitidos.push(matricula);
          } else if (matricula && modelo && filas > 0) {
            this.planes.push({ id: ++this.nextPlaneId, matricula, modelo, filas, capacidad: filas * 4 });
            creados++;
          }
        }
        return json(201, { creados, omitidos });
      }

      return json(404, { error: 'ruta_no_simulada', mensaje: `Ruta no simulada en mock: ${method} ${path}` });
    });
  }
}

export async function installSoaMock(page: Page, options?: SoaMockOptions): Promise<SoaMockController> {
  const controller = new SoaMockController(options);
  await controller.attach(page);
  return controller;
}
