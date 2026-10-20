// Carga en PRODUCCIÓN el canal (streams/main, en vivo con la señal real),
// las noticias y la parrilla de ejemplo de demoContent.js. Requiere haber
// corrido antes createTenant.js. Volver a correrlo sobrescribe los mismos
// docs (ejemplo-N, programa-N), no los duplica.
//
// Uso: node seedDemoContent.js

const { initializeApp, cert } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { addDemoContent } = require("./demoContent");
const serviceAccount = require("./serviceAccountKey.json");

initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();

const SLUG = "canal7";

async function main() {
  const publicSnap = await db.collection("tenantsPublic").doc(SLUG).get();
  if (!publicSnap.exists) {
    console.error(`No existe el tenant "${SLUG}". Corre primero: node createTenant.js`);
    process.exit(1);
  }
  const { tenantId, appName } = publicSnap.data();

  const batch = db.batch();
  addDemoContent(batch, db.collection("tenants").doc(tenantId), appName);
  await batch.commit();
  console.log(`Canal, noticias y parrilla de ejemplo cargados en tenants/${tenantId}`);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
