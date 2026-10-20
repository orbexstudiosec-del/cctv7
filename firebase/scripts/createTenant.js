// Ejecutar UNA SOLA VEZ para dar de alta el canal sin pasar por el panel
// (que no tiene pantalla de alta de tenants). Crea los mismos documentos
// que generaría la Cloud Function `createTenant`.
//
// El slug tiene que coincidir con `kTenantSlug` del panel
// (admin_panel/lib/tenant/tenant_config.dart) y con `tenantSlug` de la app
// (viewer_app/lib/main_canal7.dart).
//
// Uso: node createTenant.js

const { initializeApp, cert } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const serviceAccount = require("./serviceAccountKey.json");

initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();

const SLUG = "canal7";
const NAME = "CCTV CANAL 7";
// Colores de marca: se pueden cambiar después editando
// tenantsPublic/canal7 en la consola de Firebase.
const PRIMARY_COLOR = "#6AC827";
const SECONDARY_COLOR = "#E31E24";

async function main() {
  const publicRef = db.collection("tenantsPublic").doc(SLUG);
  const existing = await publicRef.get();
  if (existing.exists) {
    console.log(`El tenant "${SLUG}" ya existe (tenantId: ${existing.data().tenantId}).`);
    return;
  }

  const tenantRef = db.collection("tenants").doc();

  await db.runTransaction(async (tx) => {
    tx.set(tenantRef, {
      name: NAME,
      slug: SLUG,
      plan: "basic",
      status: "active",
      limits: { maxConcurrentStreams: 1, maxUsers: 5 },
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    tx.set(publicRef, {
      tenantId: tenantRef.id,
      name: NAME,
      appName: NAME,
      logoUrl: null,
      faviconUrl: null,
      primaryColor: PRIMARY_COLOR,
      secondaryColor: SECONDARY_COLOR,
    });
  });

  console.log(`Tenant creado: slug="${SLUG}", tenantId="${tenantRef.id}"`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
