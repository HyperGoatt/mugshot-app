import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json",
};

const buckets = ["visit-photos", "profile-media"];

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders });
}

async function removePrefix(
  admin: ReturnType<typeof createClient>,
  bucket: string,
  prefix: string,
): Promise<void> {
  const storage = admin.storage.from(bucket);
  // Removing the first page and listing again handles arbitrary object counts
  // without trusting an offset while the collection is changing.
  while (true) {
    const { data: entries, error } = await storage.list(prefix, {
      limit: 1000,
      offset: 0,
      sortBy: { column: "name", order: "asc" },
    });

    if (error) throw error;
    if (!entries?.length) return;

    const files = entries
      .filter((entry) => entry.id)
      .map((entry) => `${prefix}/${entry.name}`);
    const folders = entries
      .filter((entry) => !entry.id)
      .map((entry) => `${prefix}/${entry.name}`);

    for (const folder of folders) {
      await removePrefix(admin, bucket, folder);
    }

    for (let index = 0; index < files.length; index += 100) {
      const { error: removeError } = await storage.remove(files.slice(index, index + 100));
      if (removeError) throw removeError;
    }

    if (files.length === 0 && folders.length === 0) return;
  }
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return json({ error: "unauthorized" }, 401);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceRoleKey) {
    return json({ error: "service_unavailable" }, 503);
  }

  const token = authorization.slice("Bearer ".length);
  const admin = createClient(url, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  const user = userData.user;

  if (userError || !user) {
    return json({ error: "unauthorized" }, 401);
  }

  const { error: signOutError } = await admin.auth.admin.signOut(user.id, "global");
  if (signOutError) {
    console.error("delete-account session revocation failed", signOutError);
    return json({ error: "deletion_unavailable" }, 503);
  }

  try {
    const ownerPrefix = user.id.toLowerCase();
    for (const bucket of buckets) {
      await removePrefix(admin, bucket, ownerPrefix);
    }

    const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
    if (deleteError) throw deleteError;

    return json({ deleted: true });
  } catch (error) {
    console.error("delete-account failed", error);
    return json({ error: "deletion_unavailable" }, 503);
  }
});
