// Da acceso al panel a un usuario: le asigna el tenant del canal + un rol
// (custom claims, que es lo que leen las Security Rules) y deja el doc
// espejo en users/{uid}, igual que la Cloud Function `setUserRole`.
//
// 1. Crea el usuario en Firebase Console > Authentication > Add user.
// 2. node setUserRole.js correo@ejemplo.com [tenant_admin|editor|viewer]
//    (sin rol = tenant_admin)
//
// El usuario tiene que cerrar sesión y volver a entrar para que el token
// tome el rol nuevo.

const { initializeApp, cert } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const serviceAccount = require("./serviceAccountKey.json");

initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();

const SLUG = "canal7";
const ROLES = ["tenant_admin", "editor", "viewer"];

async function main() {
  const email = process.argv[2];
  const role = process.argv[3] ?? "tenant_admin";
  if (!email || !ROLES.includes(role)) {
    console.error(`Uso: node setUserRole.js correo@ejemplo.com [${ROLES.join("|")}]`);
    process.exit(1);
  }

  const publicSnap = await db.collection("tenantsPublic").doc(SLUG).get();
  if (!publicSnap.exists) {
    console.error(`No existe el tenant "${SLUG}". Corre primero: node createTenant.js`);
    process.exit(1);
  }
  const tenantId = publicSnap.data().tenantId;

  const auth = getAuth();
  const user = await auth.getUserByEmail(email);
  await auth.setCustomUserClaims(user.uid, { tenant_id: tenantId, role });
  await db.collection("users").doc(user.uid).set(
    {
      tenantId,
      role,
      email: user.email ?? null,
      displayName: user.displayName ?? null,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  console.log(`${email} ahora es ${role} de "${SLUG}" (tenantId: ${tenantId}).`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
