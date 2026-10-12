// Ejecutar UNA SOLA VEZ, en local, para crear al primer super_admin.
// (createTenant/setUserRole exigen ya ser super_admin, así que el primero
// hay que asignarlo a mano con el Admin SDK.)
//
// 1. En Firebase Console > Project settings > Service accounts >
//    "Generate new private key". Guarda el archivo como
//    firebase/scripts/serviceAccountKey.json (NUNCA subir esto a git).
// 2. Crea tu usuario normalmente (ej. desde la app o desde Auth > Add user).
// 3. node bootstrapSuperAdmin.js tu-correo@ejemplo.com

const { initializeApp, cert } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const serviceAccount = require("./serviceAccountKey.json");

initializeApp({ credential: cert(serviceAccount) });

async function main() {
  const email = process.argv[2];
  if (!email) {
    console.error("Uso: node bootstrapSuperAdmin.js correo@ejemplo.com");
    process.exit(1);
  }

  const auth = getAuth();
  const user = await auth.getUserByEmail(email);
  await auth.setCustomUserClaims(user.uid, { role: "super_admin" });

  console.log(
    `${email} ahora es super_admin. Debe cerrar sesión y volver a entrar para que el token se actualice.`
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
