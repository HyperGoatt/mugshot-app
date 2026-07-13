import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json",
};

type Preparation =
  | "espresso" | "americano" | "latte" | "cappuccino" | "cortado"
  | "flat_white" | "mocha" | "macchiato" | "drip" | "pour_over"
  | "chemex" | "french_press" | "aeropress" | "cold_brew" | "matcha"
  | "hojicha" | "tea" | "chai" | "hot_chocolate" | "unknown";

type Modifier = "regular" | "half_caf" | "decaf";

const espressoPreparations = new Set<Preparation>([
  "espresso", "americano", "latte", "cappuccino", "cortado", "flat_white",
  "mocha", "macchiato",
]);

const milkTerms = [
  "oat milk", "almond milk", "soy milk", "coconut milk", "whole milk",
  "skim milk", "2% milk", "half and half", "cream",
];

const flavorTerms = [
  "strawberry", "cherry", "orange", "peach", "raspberry", "blueberry",
  "vanilla", "caramel", "hazelnut", "cinnamon", "cardamom", "honey",
  "maple", "lavender", "rose", "pistachio", "chocolate",
];

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders });
}

function normalized(value: string): string {
  return value.normalize("NFD").replace(/[\u0300-\u036f]/g, "")
    .toLowerCase().replaceAll("-", " ").replace(/\s+/g, " ").trim();
}

function preparation(value: string): Preparation {
  const candidates: Array<[Preparation, string[]]> = [
    ["cold_brew", ["cold brew", "nitro"]],
    ["flat_white", ["flat white"]],
    ["pour_over", ["pour over", "v60", "kalita"]],
    ["french_press", ["french press"]],
    ["hot_chocolate", ["hot chocolate", "cocoa"]],
    ["cappuccino", ["cappuccino"]],
    ["americano", ["americano"]],
    ["macchiato", ["macchiato"]],
    ["cortado", ["cortado"]],
    ["espresso", ["espresso", "doppio", "ristretto", "lungo"]],
    ["chemex", ["chemex"]],
    ["aeropress", ["aeropress"]],
    ["drip", ["drip", "batch brew", "filter coffee"]],
    ["mocha", ["mocha"]],
    ["latte", ["latte"]],
    ["matcha", ["matcha"]],
    ["hojicha", ["hojicha"]],
    ["chai", ["chai"]],
    ["tea", ["tea"]],
  ];
  return candidates.find(([, terms]) => terms.some((term) => value.includes(term)))?.[0] ?? "unknown";
}

function family(prep: Preparation, value: string): string {
  if (espressoPreparations.has(prep)) return "espresso";
  if (["drip", "pour_over", "chemex", "french_press", "aeropress", "cold_brew"].includes(prep)) {
    return "brewed_coffee";
  }
  if (prep !== "unknown") return prep;
  return value.includes("coffee") ? "brewed_coffee" : "unknown";
}

function temperature(value: string, prep: Preparation): string {
  if (prep === "cold_brew") return "cold_brew";
  if (["frozen", "frappe", "frappé", "blended"].some((term) => value.includes(term))) return "frozen";
  const temperatureText = value.replaceAll("cold foam", "");
  if (["iced", "ice ", "cold ", "chilled"].some((term) => temperatureText.includes(term))) return "iced";
  return "hot";
}

function modifier(value: string): Modifier {
  if (value.includes("half caf")) return "half_caf";
  if (value.includes("decaf")) return "decaf";
  return "regular";
}

function shotCount(value: string, prep: Preparation, explicit?: number | null): number | null {
  if (explicit && explicit >= 1 && explicit <= 8) return explicit;
  const words: Array<[string, number]> = [
    ["single", 1], ["double", 2], ["doppio", 2], ["triple", 3], ["quad", 4],
  ];
  const word = words.find(([term]) => value.includes(term));
  if (word) return word[1];
  const numeric = value.match(/\b([1-8])\s*(?:espresso\s*)?shots?\b/);
  if (numeric) return Number(numeric[1]);
  return espressoPreparations.has(prep) ? 2 : null;
}

function caffeine(
  prep: Preparation,
  caffeineModifier: Modifier,
  shots: number | null,
  servingVolume: number | null,
): { milligrams: number; basis: string } | null {
  if (espressoPreparations.has(prep)) {
    const count = shots ?? 2;
    let amount = (caffeineModifier === "decaf" ? 6 : 63) * count;
    if (caffeineModifier === "half_caf") amount *= 0.5;
    return {
      milligrams: Math.round(amount * 10) / 10,
      basis: `${count} espresso shot${count === 1 ? "" : "s"} at the traditional average`,
    };
  }

  const references: Partial<Record<Preparation, [number, number, string]>> = {
    drip: [95, 240, "drip coffee"],
    pour_over: [120, 300, "pour-over coffee"],
    chemex: [120, 300, "Chemex"],
    french_press: [107, 240, "French press"],
    aeropress: [80, 240, "AeroPress"],
    cold_brew: [200, 355, "cold brew"],
    matcha: [70, 240, "matcha"],
    hojicha: [30, 240, "hojicha"],
    tea: [47, 240, "tea"],
    chai: [40, 240, "chai"],
    hot_chocolate: [9, 240, "hot chocolate"],
  };
  const reference = references[prep];
  if (!reference) return null;
  const [referenceAmount, referenceVolume, label] = reference;
  const serving = Math.max(servingVolume ?? referenceVolume, 30);
  let amount = referenceAmount * serving / referenceVolume;
  if (caffeineModifier === "half_caf") amount *= 0.5;
  if (caffeineModifier === "decaf") amount = 3 * serving / 240;
  return {
    milligrams: Math.round(amount * 10) / 10,
    basis: `${label} traditional average scaled to ${Math.round(serving)} mL`,
  };
}

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest)).map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return json({ error: "unauthorized" }, 401);

  const url = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceRoleKey) return json({ error: "service_unavailable" }, 503);

  const token = authorization.slice("Bearer ".length);
  const admin = createClient(url, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  const user = userData.user;
  if (userError || !user) return json({ error: "unauthorized" }, 401);

  const payload = await request.json().catch(() => null) as { visit_id?: string } | null;
  if (!payload?.visit_id) return json({ error: "visit_id_required" }, 400);

  const { data: visit, error: visitError } = await admin.from("visits")
    .select("id,user_id,drink_subtype,drink_type_custom,drink_type,brew_details")
    .eq("id", payload.visit_id)
    .eq("user_id", user.id)
    .maybeSingle();
  if (visitError) return json({ error: "analysis_unavailable" }, 503);
  if (!visit) return json({ error: "not_found" }, 404);

  const { data: current } = await admin.from("visit_drink_analyses")
    .select("user_overrides")
    .eq("visit_id", visit.id)
    .maybeSingle();
  const overrides = (current?.user_overrides ?? {}) as Record<string, unknown>;
  const raw = String(visit.drink_subtype || visit.drink_type_custom || visit.drink_type || "Drink").trim();
  const value = normalized(raw);
  const inferredPreparation = preparation(value);
  const prep = String(overrides.preparation ?? inferredPreparation) as Preparation;
  const servingFromVisit = Number(visit.brew_details?.servingVolumeMilliliters);
  const explicitServing = Number(overrides.serving_volume_ml ?? servingFromVisit);
  const serving = Number.isFinite(explicitServing) && explicitServing > 0 ? explicitServing : null;
  const shotFromVisit = Number(visit.brew_details?.espressoShotCount);
  const explicitShots = Number(overrides.espresso_shot_count ?? shotFromVisit);
  const shots = shotCount(value, prep, Number.isInteger(explicitShots) ? explicitShots : null);
  const caffeineModifier = modifier(value);
  const estimate = caffeine(prep, caffeineModifier, shots, serving);
  const milk = milkTerms.find((term) => value.includes(term)) ?? null;
  const flavors = flavorTerms.filter((term) => value.includes(term));
  const signals = new Set<string>();
  const resolvedTemperature = String(overrides.temperature ?? temperature(value, prep));
  if (resolvedTemperature !== "hot") signals.add("chooses_cold_drinks");
  if (milk) signals.add("chooses_milk_drinks");
  if (flavors.length) signals.add("chooses_flavored_drinks");
  if (flavorTerms.slice(0, 6).some((term) => value.includes(term))) {
    signals.add("chooses_fruit_flavors");
    signals.add("chooses_sweet_flavors");
  }
  if (["syrup", "sugar", "sweet", "honey", "caramel", "vanilla"].some((term) => value.includes(term))) {
    signals.add("chooses_sweetened_drinks");
  }

  const row = {
    visit_id: visit.id,
    user_id: visit.user_id,
    raw_drink_name: raw,
    raw_drink_hash: await sha256(value),
    analysis_schema_version: 1,
    parser_version: "edge-rules-1",
    caffeine_reference_version: "traditional-averages-1",
    processing_status: "complete",
    canonical_family: String(overrides.canonical_family ?? family(prep, value)),
    preparation: prep,
    temperature: resolvedTemperature,
    caffeine_modifier: caffeineModifier,
    espresso_shot_count: shots,
    serving_volume_ml: serving,
    estimated_caffeine_mg: estimate?.milligrams ?? null,
    caffeine_calculation_basis: estimate?.basis ?? null,
    caffeine_coverage: estimate ? "estimated" : "excluded",
    preference_signals: Array.from(signals).sort(),
    confidence: prep === "unknown" ? 0.25 : 0.9,
    provenance: "edge_rules",
    model_output: { milk, flavors },
    user_overrides: overrides,
    updated_at: new Date().toISOString(),
  };

  const { error: upsertError } = await admin.from("visit_drink_analyses")
    .upsert(row, { onConflict: "visit_id" });
  if (upsertError) {
    console.error("drink analysis upsert failed", upsertError);
    return json({ error: "analysis_unavailable" }, 503);
  }

  return json({ accepted: true });
});
