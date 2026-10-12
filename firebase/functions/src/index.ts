import { onCall, HttpsError } from "firebase-functions/v2/https";
import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";

initializeApp();
const db = getFirestore();

type Role = "super_admin" | "tenant_admin" | "editor" | "viewer";

interface AuthClaims {
  role?: Role;
  tenant_id?: string;
}

function assertSuperAdmin(authToken: AuthClaims | undefined) {
  if (!authToken || authToken.role !== "super_admin") {
    throw new HttpsError("permission-denied", "Solo un super admin puede hacer esto.");
  }
}

/**
 * Crea un nuevo tenant: doc interno (tenants/{id}) + doc público de marca
 * (tenantsPublic/{slug}), en una sola transacción. Solo el super admin
 * puede llamar esto (alta de clientes nuevos).
 */
export const createTenant = onCall(async (request) => {
  assertSuperAdmin(request.auth?.token as AuthClaims | undefined);

  const { name, slug, plan = "basic", branding } = (request.data ?? {}) as {
    name: string;
    slug: string;
    plan?: string;
    branding?: {
      logoUrl?: string;
      faviconUrl?: string;
      primaryColor?: string;
      secondaryColor?: string;
      appName?: string;
    };
  };

  if (!name || !slug) {
    throw new HttpsError("invalid-argument", "name y slug son obligatorios.");
  }

  const normalizedSlug = slug.toLowerCase().trim();
  if (!/^[a-z0-9-]+$/.test(normalizedSlug)) {
    throw new HttpsError(
      "invalid-argument",
      "slug solo puede tener minúsculas, números y guiones (se usa como subdominio)."
    );
  }

  const publicRef = db.collection("tenantsPublic").doc(normalizedSlug);
  const existing = await publicRef.get();
  if (existing.exists) {
    throw new HttpsError("already-exists", `El slug "${normalizedSlug}" ya está en uso.`);
  }

  const tenantRef = db.collection("tenants").doc();

  await db.runTransaction(async (tx) => {
    tx.set(tenantRef, {
      name,
      slug: normalizedSlug,
      plan,
      status: "active",
      limits: { maxConcurrentStreams: 1, maxUsers: 5 },
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    tx.set(publicRef, {
      tenantId: tenantRef.id,
      name,
      appName: branding?.appName ?? name,
      logoUrl: branding?.logoUrl ?? null,
      faviconUrl: branding?.faviconUrl ?? null,
      primaryColor: branding?.primaryColor ?? "#1A73E8",
      secondaryColor: branding?.secondaryColor ?? "#F5A623",
    });
  });

  return { tenantId: tenantRef.id, slug: normalizedSlug };
});

/**
 * Asigna tenant + rol a un usuario: custom claims (fuente de verdad para las
 * Security Rules) + doc espejo en users/{uid} (para poder listar/filtrar
 * usuarios desde el panel, ya que los claims no son consultables).
 *
 * Puede llamarla:
 *  - el super_admin, para cualquier tenant/rol.
 *  - un tenant_admin, solo dentro de su propio tenant y nunca para crear
 *    otro tenant_admin (evita que un cliente se auto-promueva).
 */
export const setUserRole = onCall(async (request) => {
  const callerToken = request.auth?.token as AuthClaims | undefined;
  if (!callerToken) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
  }

  const { uid, tenantId, role } = (request.data ?? {}) as {
    uid: string;
    tenantId: string;
    role: Role;
  };

  if (!uid || !tenantId || !role) {
    throw new HttpsError("invalid-argument", "uid, tenantId y role son obligatorios.");
  }

  const isSuperAdmin = callerToken.role === "super_admin";
  const isOwnTenantAdmin =
    callerToken.role === "tenant_admin" && callerToken.tenant_id === tenantId;

  if (!isSuperAdmin && !isOwnTenantAdmin) {
    throw new HttpsError("permission-denied", "No puedes asignar roles en este tenant.");
  }

  if (!isSuperAdmin && role === "tenant_admin") {
    throw new HttpsError(
      "permission-denied",
      "Solo el super admin puede crear otro tenant_admin."
    );
  }

  await getAuth().setCustomUserClaims(uid, { tenant_id: tenantId, role });

  const userRecord = await getAuth().getUser(uid);
  await db.collection("users").doc(uid).set(
    {
      tenantId,
      role,
      email: userRecord.email ?? null,
      displayName: userRecord.displayName ?? null,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  // El cliente debe forzar un refresh del ID token (getIdToken(true) o
  // re-login) para que este cambio de claims surta efecto en su sesión.
  return { ok: true };
});
