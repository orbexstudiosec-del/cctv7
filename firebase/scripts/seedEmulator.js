// Datos de prueba para el emulador local de Firestore (no toca producción:
// solo corre si FIRESTORE_EMULATOR_HOST está definido). Crea el tenant
// "canal7" con su canal apuntando a la señal real.
//
// Uso (con `firebase emulators:start` corriendo en firebase/):
//   $env:FIRESTORE_EMULATOR_HOST="127.0.0.1:8080"
//   $env:FIREBASE_AUTH_EMULATOR_HOST="127.0.0.1:9099"   # opcional: crea el admin del panel
//   node seedEmulator.js

const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const { addDemoContent } = require("./demoContent");

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error("Falta FIRESTORE_EMULATOR_HOST: este script es solo para el emulador.");
  process.exit(1);
}

initializeApp({ projectId: "canal7app" });
const db = getFirestore();

const SLUG = "canal7";
const TENANT_ID = "canal7-local";
const NAME = "CCTV CANAL 7";
// Solo existe en el emulador de Auth.
const ADMIN_EMAIL = "admin@canal7.local";
const ADMIN_PASSWORD = "canal7admin";

async function main() {
  const tenantRef = db.collection("tenants").doc(TENANT_ID);
  const batch = db.batch();

  batch.set(tenantRef, {
    name: NAME,
    slug: SLUG,
    plan: "basic",
    status: "active",
    limits: { maxConcurrentStreams: 1, maxUsers: 5 },
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  batch.set(db.collection("tenantsPublic").doc(SLUG), {
    tenantId: TENANT_ID,
    name: NAME,
    appName: NAME,
    logoUrl: null,
    faviconUrl: null,
    primaryColor: "#6AC827",
    secondaryColor: "#E31E24",
  });

  addDemoContent(batch, tenantRef, NAME);

  await batch.commit();
  console.log(`Emulador sembrado: tenantsPublic/${SLUG} -> tenants/${TENANT_ID}`);

  // Admin del panel (solo si también corre el emulador de Auth).
  if (process.env.FIREBASE_AUTH_EMULATOR_HOST) {
    const auth = getAuth();
    const user = await auth
      .getUserByEmail(ADMIN_EMAIL)
      .catch(() => auth.createUser({ email: ADMIN_EMAIL, password: ADMIN_PASSWORD }));
    await auth.setCustomUserClaims(user.uid, { tenant_id: TENANT_ID, role: "tenant_admin" });
    await db.collection("users").doc(user.uid).set({
      email: ADMIN_EMAIL,
      tenantId: TENANT_ID,
      role: "tenant_admin",
    });
    console.log(`Admin del panel: ${ADMIN_EMAIL} / ${ADMIN_PASSWORD}`);
  }
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
