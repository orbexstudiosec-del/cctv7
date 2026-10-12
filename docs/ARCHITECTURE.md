# Arquitectura multi-tenant (Firebase) — punto de partida

Panel admin + apps Flutter white-label para N clientes, sobre un solo proyecto
Firebase. El servidor de video/streaming vive en otro servicio (fuera de este
documento); aquí solo se cubre lo que maneja Firebase: identidad, datos,
configuración de marca y metadata de los streams.

## 1. Modelo de tenants

Cada cliente (gimnasio, iglesia, academia, etc.) es un **tenant**. Un usuario
pertenece a exactamente un tenant, excepto tú (super admin), que puede ver
todos.

Custom claims en el ID token de Firebase Auth (fuente de verdad para las
Security Rules, no se pueden falsificar desde el cliente):

```json
{
  "tenant_id": "abc123",
  "role": "super_admin | tenant_admin | editor | viewer"
}
```

- `super_admin`: tú. Sin `tenant_id`, ve y administra todos los tenants.
- `tenant_admin`: administrador del cliente. Gestiona su marca, sus streams,
  sus usuarios.
- `editor`: puede crear/editar streams de su tenant, no gestiona usuarios.
- `viewer`: solo lectura (ej. alguien del equipo del cliente que solo consulta).

## 2. Esquema de Firestore

```
tenants/{tenantId}
  name: string
  slug: string              // mismo valor que el doc id de tenantsPublic
  plan: "free" | "basic" | "pro"
  status: "active" | "suspended" | "trial"
  limits: { maxConcurrentStreams: number, maxUsers: number }
  createdAt, updatedAt: timestamp

  tenants/{tenantId}/streams/{streamId}
    title: string
    description: string
    status: "scheduled" | "live" | "ended"
    provider: string            // "mux" | "cloudflare" | "custom" | ...
    externalStreamId: string    // id en tu servicio de streaming externo
    playbackUrl: string         // HLS/DASH público
    thumbnailUrl: string
    scheduledAt, startedAt, endedAt: timestamp
    viewerCount: number
    createdBy: uid
    createdAt: timestamp

    tenants/{tenantId}/streams/{streamId}/private/ingest   (doc único "ingest")
      rtmpUrl: string
      streamKey: string          // credenciales sensibles, nunca al viewer

tenantsPublic/{slug}            // doc id = slug (subdominio), lectura pública
  tenantId: string
  name: string
  appName: string
  logoUrl: string | null
  faviconUrl: string | null
  primaryColor: string          // hex
  secondaryColor: string        // hex

users/{uid}                     // espejo de los custom claims, para listar/filtrar en el panel
  tenantId: string
  role: string
  email: string
  displayName: string
  createdAt, updatedAt: timestamp
```

**Por qué `tenantsPublic` separado de `tenants`:** la pantalla de login del
panel necesita mostrar el logo/colores del cliente *antes* de autenticar
(solo sabe el subdominio). `tenantsPublic/{slug}` expone únicamente lo que es
seguro hacer público (marca), mientras que `tenants/{tenantId}` guarda datos
internos (plan, límites) que sí requieren autenticación.

**Por qué `private/ingest` aparte del doc del stream:** la clave RTMP no debe
viajar al cliente viewer. Al vivir en un subdocumento con sus propias reglas,
un `viewer` puede leer título/estado/thumbnail del stream sin poder leer la
credencial de ingesta.

## 3. Reglas de seguridad

Ver [`firebase/firestore.rules`](../firebase/firestore.rules) y
[`firebase/storage.rules`](../firebase/storage.rules). Idea central: todo
pasa por `request.auth.token.tenant_id` / `.role`, nunca por un campo que el
cliente pueda escribir.

## 4. Storage (logos, thumbnails)

```
tenants/{tenantId}/branding/logo.png
tenants/{tenantId}/branding/favicon.png
tenants/{tenantId}/streams/{streamId}/thumbnail.jpg
```

Lectura pública (se muestran antes de login / en la app), escritura solo
`tenant_admin` de ese tenant o `super_admin`.

## 5. Flujo de resolución por subdominio

Objetivo: `cliente1.tupanel.com` muestra el logo/colores de "cliente1" desde
el primer render, sin esperar al login.

1. El panel carga en `cliente1.tupanel.com`.
2. JS extrae el subdominio: `location.hostname.split(".")[0]` → `"cliente1"`.
3. Lectura directa (sin auth, 1 sola lectura por doc id, no query) a
   `tenantsPublic/cliente1`.
4. Si existe → aplica `logoUrl`, `primaryColor`, `secondaryColor`, `appName`
   a la UI y muestra el login ya con la marca del cliente.
5. Si no existe → redirige al dominio principal o muestra "tenant no
   encontrado".
6. El usuario inicia sesión con Firebase Auth normalmente.
7. Tras el login, el cliente lee el ID token (`getIdTokenResult()`) y
   verifica `claims.tenant_id === tenantId` (el id resuelto en el paso 3,
   guardado junto al slug). Si no coincide — alguien intentando entrar por
   la URL de un cliente que no es el suyo — se cierra sesión y se muestra
   error.
8. Las Security Rules son la garantía real (el paso 7 es solo UX): aunque
   alguien se salte el frontend, Firestore nunca le devolverá datos de un
   `tenant_id` distinto al de su token.

Ejemplo de referencia (independiente del framework que elijan para el panel):

```js
async function resolveTenantBySubdomain() {
  const slug = location.hostname.split(".")[0];
  const snap = await getDoc(doc(db, "tenantsPublic", slug));
  if (!snap.exists()) return null;
  return { slug, ...snap.data() };
}

function applyBranding(tenant) {
  document.title = tenant.appName;
  document.documentElement.style.setProperty("--color-primary", tenant.primaryColor);
  document.documentElement.style.setProperty("--color-secondary", tenant.secondaryColor);
  document.querySelector('link[rel="icon"]').href = tenant.faviconUrl ?? "/favicon.ico";
}

// Tras el login:
async function verifyTenantMatch(expectedTenantId) {
  const result = await auth.currentUser.getIdTokenResult();
  if (result.claims.tenant_id !== expectedTenantId) {
    await auth.signOut();
    throw new Error("Esta cuenta no pertenece a este panel.");
  }
}
```

## 6. Dominios (Firebase Hosting)

Recomendado: un solo Hosting site + un dominio **wildcard**
(`*.tupanel.com`) agregado como custom domain, apuntando todo al mismo
`index.html`. La resolución de marca ocurre en runtime (paso 2-4 arriba), no
hace falta un site de Hosting por cliente.

Alternativa si el wildcard no está disponible en tu región/plan: un solo
dominio (`tupanel.com`) y pedir el "código de organización" (el slug) como
paso previo al login, o usar rutas (`tupanel.com/t/cliente1`).

## 7. Cloud Functions

Ver [`firebase/functions/src/index.ts`](../firebase/functions/src/index.ts).

- `createTenant` (callable, solo `super_admin`): crea `tenants/{id}` +
  `tenantsPublic/{slug}` en una transacción, valida que el slug no exista.
- `setUserRole` (callable, `super_admin` o `tenant_admin` de su propio
  tenant): asigna `tenant_id`/`role` como custom claims + actualiza
  `users/{uid}`. Un `tenant_admin` no puede crear otro `tenant_admin` ni
  tocar otro tenant.

**Importante:** después de cambiar los claims de un usuario, su sesión
actual no se entera hasta que el cliente fuerza el refresh del token
(`getIdToken(true)` o re-login). Avísalo en el flujo de invitación de
usuarios del panel.

## 8. Arranque (bootstrap del primer super_admin)

`createTenant`/`setUserRole` exigen ya ser `super_admin` — problema del
huevo y la gallina para el primer usuario. Para eso:
`firebase/scripts/bootstrapSuperAdmin.js`, un script local de una sola
ejecución que usa una service account key (nunca subir esa key a git) para
asignarte el claim `super_admin` directamente.

## 9. Próximos pasos

1. Crear el proyecto en Firebase console, habilitar Auth (email/password al
   menos), Firestore, Storage, Functions (plan Blaze).
2. `cd firebase && firebase init` (o copiar `.firebaserc.example` →
   `.firebaserc` con tu project id real).
3. `firebase deploy --only firestore:rules,storage:rules`.
4. `cd functions && npm install && npm run deploy`.
5. Crear tu usuario en Auth, correr `bootstrapSuperAdmin.js` con tu correo.
6. Desde el panel (o con una llamada manual a la función), crear el primer
   tenant de prueba y confirmar que `cliente1.tupanel.com` (o el dominio que
   uses en local) pinta su marca antes del login.
7. Elegir framework del panel web (Flutter Web / React / Next) — el flujo de
   arriba es el mismo en cualquiera.
8. Definir flavors de la app Flutter (uno por cliente) y apuntarlos al mismo
   proyecto Firebase, cada uno con su propio `tenant_id` embebido en config.
