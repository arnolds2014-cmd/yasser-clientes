import { createClient } from "npm:@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "npm:jose@5.9.6";

const webhookSecret = Deno.env.get("YASSER_WEBHOOK_SECRET");
const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!webhookSecret || !serviceAccountJson || !supabaseUrl || !serviceRoleKey) {
  throw new Error("Missing push notification function secrets.");
}

const serviceAccount = JSON.parse(serviceAccountJson) as {
  client_email: string;
  private_key: string;
  project_id: string;
};
const admin = createClient(supabaseUrl, serviceRoleKey);
const oauthUrl = "https://oauth2.googleapis.com/token";
let cachedAccessToken: { value: string; expiresAt: number } | undefined;

async function getAccessToken(): Promise<string> {
  if (cachedAccessToken && cachedAccessToken.expiresAt > Date.now() + 60_000) {
    return cachedAccessToken.value;
  }

  const privateKey = await importPKCS8(
    serviceAccount.private_key.replace(/\\n/g, "\n"),
    "RS256",
  );
  const assertion = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(serviceAccount.client_email)
    .setAudience(oauthUrl)
    .setIssuedAt()
    .setExpirationTime("1h")
    .sign(privateKey);

  const response = await fetch(oauthUrl, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) {
    throw new Error(`Firebase OAuth failed (${response.status}).`);
  }

  const tokenResponse = await response.json();
  cachedAccessToken = {
    value: tokenResponse.access_token,
    expiresAt: Date.now() + tokenResponse.expires_in * 1000,
  };
  return cachedAccessToken.value;
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }
  if (request.headers.get("x-yasser-webhook-secret") !== webhookSecret) {
    return new Response("Unauthorized", { status: 401 });
  }

  const payload = await request.json();
  const record = payload.record;
  if (
    payload.type !== "INSERT" ||
    payload.table !== "yasser_messages" ||
    typeof record?.sender_id !== "string" ||
    typeof record?.recipient_id !== "string"
  ) {
    return new Response("Ignored event", { status: 200 });
  }

  const [{ data: tokens, error: tokenError }, { data: sender, error: senderError }] =
    await Promise.all([
      admin
        .from("yasser_push_tokens")
        .select("token")
        .eq("user_id", record.recipient_id),
      admin
        .from("yasser_profiles")
        .select("username")
        .eq("id", record.sender_id)
        .maybeSingle(),
    ]);
  if (tokenError) throw tokenError;
  if (senderError) throw senderError;
  if (!tokens?.length) return Response.json({ sent: 0 });

  const accessToken = await getAccessToken();
  const endpoint =
    `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;
  const title = `Nuevo mensaje de ${sender?.username ?? "tu chat"}`;
  const results = await Promise.all(
    tokens.map(async ({ token }) => {
      const response = await fetch(endpoint, {
        method: "POST",
        headers: {
          authorization: `Bearer ${accessToken}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token,
            notification: {
              title,
              body: "Abre Barbería YASSER para responder.",
            },
            data: {
              sender_id: record.sender_id,
              message_id: record.id ?? "",
            },
            android: { priority: "high" },
          },
        }),
      });
      if (response.ok) return { ok: true };

      const responseBody = await response.json();
      const details = Array.isArray(responseBody.error?.details)
        ? responseBody.error.details
        : [];
      if (
        response.status === 404 ||
        details.some((detail: { errorCode?: string }) =>
          detail.errorCode === "UNREGISTERED"
        )
      ) {
        const { error } = await admin
          .from("yasser_push_tokens")
          .delete()
          .eq("token", token);
        if (error) throw error;
        return { ok: true };
      }
      return { ok: false, status: response.status };
    }),
  );

  const failed = results.filter((result) => !result.ok);
  if (failed.length) {
    console.error("FCM delivery failed for one or more registered devices.");
    return Response.json({ sent: tokens.length - failed.length }, { status: 502 });
  }
  return Response.json({ sent: tokens.length });
});
