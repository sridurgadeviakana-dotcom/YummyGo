const FIREBASE_JWKS_URL =
  "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";

let firebaseKeys;
let firebaseKeysExpiresAt = 0;
let serviceAccountToken;
let serviceAccountTokenExpiresAt = 0;

export default {
  async fetch(request, env) {
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "Authorization, Content-Type",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Content-Type": "application/json",
    };

    const url = new URL(request.url);
    if (request.method === "GET" && url.pathname.replace(/\/+$/, "") === "/health") {
      return json({ status: "ok" }, 200, corsHeaders);
    }

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders });
    }
    if (request.method !== "POST") {
      return json({ error: "Method not allowed." }, 405, corsHeaders);
    }

    try {
      if (!env.RAZORPAY_KEY_ID?.startsWith("rzp_test_")) {
        throw new HttpError(
          503,
          "Razorpay test mode is not configured on this Worker.",
        );
      }
      if (!env.RAZORPAY_KEY_SECRET || !env.FIREBASE_PROJECT_ID) {
        throw new HttpError(503, "Payment service configuration is incomplete.");
      }

      const userId = await authenticateFirebase(request, env.FIREBASE_PROJECT_ID);
      const firestoreToken = await getServiceAccountToken(env);
      const body = await request.json();
      const path = new URL(request.url).pathname.replace(/\/+$/, "");
      let result;

      if (path.endsWith("/create-order")) {
        result = await createOrder(body, userId, firestoreToken, env);
      } else if (path.endsWith("/verify-payment")) {
        result = await verifyPayment(body, userId, firestoreToken, env);
      } else {
        throw new HttpError(404, "Payment endpoint not found.");
      }

      return json(result, 200, corsHeaders);
    } catch (error) {
      const status = error instanceof HttpError ? error.status : 500;
      if (status === 500) console.error("Payment Worker error:", error);
      return json(
        {
          error: status === 500 ? "Payment request failed." : error.message,
          message: status === 500 ? "Payment request failed." : error.message,
        },
        status,
        corsHeaders,
      );
    }
  },
};

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

function json(value, status, headers) {
  return new Response(JSON.stringify(value), { status, headers });
}

function decodeBase64Url(value) {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  return Uint8Array.from(atob(normalized), (character) =>
    character.charCodeAt(0),
  );
}

async function authenticateFirebase(request, projectId) {
  const token = request.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  const parts = token?.split(".");
  if (!parts || parts.length !== 3) {
    throw new HttpError(401, "Please sign in to continue.");
  }

  let header;
  let claims;
  try {
    header = JSON.parse(new TextDecoder().decode(decodeBase64Url(parts[0])));
    claims = JSON.parse(new TextDecoder().decode(decodeBase64Url(parts[1])));
  } catch {
    throw new HttpError(401, "Invalid sign-in token.");
  }

  if (header.alg !== "RS256" || typeof header.kid !== "string") {
    throw new HttpError(401, "Invalid sign-in token.");
  }

  const now = Math.floor(Date.now() / 1000);
  if (
    claims.aud !== projectId ||
    claims.iss !== `https://securetoken.google.com/${projectId}` ||
    typeof claims.sub !== "string" ||
    claims.sub.length === 0 ||
    typeof claims.exp !== "number" ||
    claims.exp <= now ||
    typeof claims.iat !== "number" ||
    claims.iat > now
  ) {
    throw new HttpError(401, "Sign-in token is expired or invalid.");
  }

  const keys = await getFirebaseKeys();
  const jwk = keys.find((key) => key.kid === header.kid);
  if (!jwk) throw new HttpError(401, "Sign-in token key is not recognized.");

  const publicKey = await crypto.subtle.importKey(
    "jwk",
    jwk,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"],
  );
  const isValid = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    publicKey,
    decodeBase64Url(parts[2]),
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
  );
  if (!isValid) throw new HttpError(401, "Sign-in token is invalid.");

  return claims.sub;
}

function base64UrlEncode(value) {
  const bytes =
    typeof value === "string" ? new TextEncoder().encode(value) : value;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

async function getServiceAccountToken(env) {
  if (serviceAccountToken && Date.now() < serviceAccountTokenExpiresAt) {
    return serviceAccountToken;
  }
  const serviceAccountJson =
    env.FIREBASE_SERVICE_ACCOUNT_JSON ?? env.FIREBASE_SERVICE_ACCOUNT;
  if (!serviceAccountJson) {
    throw new HttpError(503, "Firebase service account is not configured.");
  }

 let account;

try {
  const raw = String(serviceAccountJson).trim();

  console.log("Firebase secret diagnostic:", {
    length: raw.length,
    startsWithBrace: raw.startsWith("{"),
    endsWithBrace: raw.endsWith("}"),
    hasClientEmail: raw.includes('"client_email"'),
    hasPrivateKey: raw.includes('"private_key"'),
  });

  account = JSON.parse(raw);
} catch (error) {
  console.error("Firebase JSON parsing failed:", error.message);

  throw new HttpError(
    503,
    "Firebase service account configuration is invalid."
  );
}

  const now = Math.floor(Date.now() / 1000);
  const header = base64UrlEncode(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payload = base64UrlEncode(
    JSON.stringify({
      iss: account.client_email,
      scope: "https://www.googleapis.com/auth/datastore",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    }),
  );
  const unsignedToken = `${header}.${payload}`;
  const privateKeyDer = decodeBase64Url(
    account.private_key
      .replace(/-----BEGIN PRIVATE KEY-----/g, "")
      .replace(/-----END PRIVATE KEY-----/g, "")
      .replace(/\s/g, ""),
  );
  let privateKey;
  try {
    privateKey = await crypto.subtle.importKey(
      "pkcs8",
      privateKeyDer,
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["sign"],
    );
  } catch {
    throw new HttpError(503, "Firebase service account private key is invalid.");
  }
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    privateKey,
    new TextEncoder().encode(unsignedToken),
  );
  const assertion = `${unsignedToken}.${base64UrlEncode(new Uint8Array(signature))}`;
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const result = await response.json();
  if (!response.ok || typeof result.access_token !== "string") {
    console.error("Firebase service token error:", response.status, result);
    throw new HttpError(503, "Unable to authenticate with Firestore.");
  }

  serviceAccountToken = result.access_token;
  serviceAccountTokenExpiresAt = Date.now() + 50 * 60 * 1000;
  return serviceAccountToken;
}

async function getFirebaseKeys() {
  if (firebaseKeys && Date.now() < firebaseKeysExpiresAt) return firebaseKeys;

  const response = await fetch(FIREBASE_JWKS_URL);
  if (!response.ok) throw new HttpError(503, "Unable to validate sign-in.");
  const data = await response.json();
  firebaseKeys = data.keys;
  const maxAge = Number(
    response.headers.get("Cache-Control")?.match(/max-age=(\d+)/)?.[1] ?? 3600,
  );
  firebaseKeysExpiresAt = Date.now() + maxAge * 1000;
  return firebaseKeys;
}

function firestoreValue(value) {
  if (!value || typeof value !== "object") return value;
  if ("stringValue" in value) return value.stringValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return Number(value.doubleValue);
  if ("booleanValue" in value) return value.booleanValue;
  if ("nullValue" in value) return null;
  if ("timestampValue" in value) return value.timestampValue;
  if ("arrayValue" in value) {
    return (value.arrayValue.values ?? []).map(firestoreValue);
  }
  if ("mapValue" in value) return firestoreFields(value.mapValue.fields ?? {});
  return value;
}

function firestoreFields(fields = {}) {
  return Object.fromEntries(
    Object.entries(fields).map(([key, value]) => [key, firestoreValue(value)]),
  );
}

function firestoreDocument(document) {
  return firestoreFields(document.fields ?? {});
}

function firestoreWriteValue(value) {
  if (value === null) return { nullValue: null };
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number") {
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(firestoreWriteValue) } };
  }
  if (value instanceof Date) {
    return { timestampValue: value.toISOString() };
  }
  if (typeof value === "object") {
    return {
      mapValue: {
        fields: Object.fromEntries(
          Object.entries(value).map(([key, item]) => [
            key,
            firestoreWriteValue(item),
          ]),
        ),
      },
    };
  }
  throw new HttpError(500, "Unsupported Firestore field value.");
}

function firestoreBase(env) {
  return `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(
    env.FIREBASE_PROJECT_ID,
  )}/databases/(default)/documents`;
}

async function firestoreRequest(path, token, options = {}) {
  const { env, ...requestOptions } = options;
  const response = await fetch(`${firestoreBase(env)}${path}`, {
    ...requestOptions,
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      ...requestOptions.headers,
    },
  });
  if (response.status === 404) return null;
  if (!response.ok) {
    const text = await response.text();
    console.error("Firestore request failed:", response.status, text);
    throw new HttpError(502, "Unable to validate the group order.");
  }
  return response.status === 204 ? null : response.json();
}

async function getFirestoreDocument(path, token, env) {
  return firestoreRequest(path, token, { env });
}

async function updateFirestoreDocument(path, fields, updateTime, token, env) {
  const url = new URL(`${firestoreBase(env)}${path}`);
  for (const field of Object.keys(fields)) {
    url.searchParams.append("updateMask.fieldPaths", field);
  }
  url.searchParams.set("currentDocument.updateTime", updateTime);
  const response = await fetch(url, {
    method: "PATCH",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      fields: Object.fromEntries(
        Object.entries(fields).map(([key, value]) => [
          key,
          firestoreWriteValue(value),
        ]),
      ),
    }),
  });
  if (response.status === 409 || response.status === 412) {
    throw new HttpError(
      409,
      "The group changed during payment verification. Refresh the group status.",
    );
  }
  if (!response.ok) {
    const details = await response.text();
    console.error("Firestore payment update failed:", response.status, details);
    throw new HttpError(502, "Unable to save the verified group payment.");
  }
  return response.json();
}

async function requireGroupMember(groupId, userId, token, env) {
  if (typeof groupId !== "string" || !/^[A-Za-z0-9_-]+$/.test(groupId)) {
    throw new HttpError(400, "Invalid group ID.");
  }
  const member = await getFirestoreDocument(
    `/group_orders/${groupId}/members/${encodeURIComponent(userId)}`,
    token,
    env,
  );
  if (!member) throw new HttpError(403, "You are not a group member.");
}

async function readCart(groupId, token, env) {
  const parent =
    `projects/${encodeURIComponent(env.FIREBASE_PROJECT_ID)}` +
    `/databases/(default)/documents/group_orders/${groupId}`;
  const response = await fetch(
    `https://firestore.googleapis.com/v1/${parent}:runQuery`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        structuredQuery: {
          from: [{ collectionId: "cart" }],
        },
      }),
    },
  );
  if (!response.ok) {
    console.error("Firestore cart query failed:", response.status, await response.text());
    throw new HttpError(502, "Unable to validate the group cart.");
  }
  return (await response.json())
    .map((entry) => entry.document)
    .filter(Boolean);
}

async function calculateCartTotal(groupId, token, env) {
  const cart = await readCart(groupId, token, env);
  if (cart.length === 0) throw new HttpError(400, "The group cart is empty.");

  const lines = await Promise.all(
    cart.map(async (document) => {
      const item = firestoreDocument(document);
      if (
        typeof item.foodId !== "string" ||
        !Number.isInteger(item.quantity) ||
        item.quantity <= 0
      ) {
        throw new HttpError(400, "A group cart item is invalid.");
      }
      const foodDocument = await getFirestoreDocument(
        `/food_items/${encodeURIComponent(item.foodId)}`,
        token,
        env,
      );
      if (!foodDocument) throw new HttpError(400, "A menu item is unavailable.");
      const food = firestoreDocument(foodDocument);
      const price = Number(food.price);
      if (!Number.isFinite(price) || price <= 0) {
        throw new HttpError(400, "A menu item has an invalid price.");
      }
      return Math.round(price * 100) * item.quantity;
    }),
  );

  const total = lines.reduce((sum, amount) => sum + amount, 0);
  if (!Number.isSafeInteger(total) || total <= 0) {
    throw new HttpError(400, "The group cart total is invalid.");
  }
  return total;
}

function razorpayAuthorization(env) {
  return `Basic ${btoa(`${env.RAZORPAY_KEY_ID}:${env.RAZORPAY_KEY_SECRET}`)}`;
}

async function razorpayRequest(path, env, method = "GET", body) {
  const response = await fetch(`https://api.razorpay.com/v1${path}`, {
    method,
    headers: {
      Authorization: razorpayAuthorization(env),
      "Content-Type": "application/json",
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const result = await response.json();
  if (!response.ok) {
    console.error("Razorpay API error:", response.status, result);
    throw new HttpError(502, "Razorpay could not process the test payment.");
  }
  return result;
}

async function createOrder(body, userId, token, env) {
  const groupId = body?.groupId;
  const expectedAmount = body?.expectedAmount;
  await requireGroupMember(groupId, userId, token, env);
  const group = await getFirestoreDocument(
    `/group_orders/${groupId}`,
    token,
    env,
  );
  if (!group) throw new HttpError(404, "Group order not found.");
  const groupData = firestoreDocument(group);
  if (groupData.paymentStatus === "paid" || groupData.paidBy) {
    throw new HttpError(409, "The restaurant payment is already recorded.");
  }
  if (groupData.status && groupData.status !== "open" && groupData.status !== "locked") {
    throw new HttpError(409, "This group is not available for checkout.");
  }
  const amount = await calculateCartTotal(groupId, token, env);
  if (expectedAmount !== amount) {
    throw new HttpError(409, "The group cart changed. Review the total.");
  }

  const order = await razorpayRequest(
    "/orders",
    env,
    "POST",
    {
      amount,
      currency: "INR",
      receipt: `yg_${crypto.randomUUID().replace(/-/g, "").slice(0, 20)}`,
      notes: { groupId, userId, mode: "test" },
    },
  );
  return {
    keyId: env.RAZORPAY_KEY_ID,
    orderId: order.id,
    amount: order.amount,
    currency: order.currency,
  };
}

async function verifyPayment(body, userId, token, env) {
  const { groupId, orderId, paymentId, signature } = body ?? {};
  if (
    typeof orderId !== "string" ||
    typeof paymentId !== "string" ||
    typeof signature !== "string" ||
    !/^[a-f0-9]{64}$/i.test(signature)
  ) {
    throw new HttpError(400, "Invalid Razorpay payment response.");
  }
  await requireGroupMember(groupId, userId, token, env);
  const groupDocument = await getFirestoreDocument(
    `/group_orders/${groupId}`,
    token,
    env,
  );
  if (!groupDocument) throw new HttpError(404, "Group order not found.");

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(env.RAZORPAY_KEY_SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const expected = new Uint8Array(
    await crypto.subtle.sign(
      "HMAC",
      key,
      new TextEncoder().encode(`${orderId}|${paymentId}`),
    ),
  );
  const actual = Uint8Array.from(
    signature.match(/.{2}/g) ?? [],
    (byte) => Number.parseInt(byte, 16),
  );
  if (
    expected.length !== actual.length ||
    expected.some((byte, index) => byte !== actual[index])
  ) {
    throw new HttpError(403, "Razorpay payment signature is invalid.");
  }

  const [order, payment] = await Promise.all([
    razorpayRequest(`/orders/${encodeURIComponent(orderId)}`, env),
    razorpayRequest(`/payments/${encodeURIComponent(paymentId)}`, env),
  ]);
  if (
    order.notes?.groupId !== groupId ||
    order.notes?.userId !== userId ||
    order.currency !== "INR" ||
    payment.order_id !== orderId ||
    payment.amount !== order.amount ||
    payment.currency !== "INR"
  ) {
    throw new HttpError(403, "Razorpay payment does not match this group.");
  }

  let capturedPayment = payment;
  if (capturedPayment.status === "authorized") {
    capturedPayment = await razorpayRequest(
      `/payments/${encodeURIComponent(paymentId)}/capture`,
      env,
      "POST",
      { amount: order.amount, currency: order.currency },
    );
  }
  if (capturedPayment.status !== "captured") {
    throw new HttpError(409, "Razorpay test payment is not captured.");
  }

  const groupData = firestoreDocument(groupDocument);
  if (groupData.paymentStatus === "paid" || groupData.paidBy) {
    const savedPayment = groupData.restaurantPayment;
    if (
      groupData.paidBy === userId &&
      groupData.paymentId === paymentId
    ) {
      return {
        verified: true,
        amount: order.amount,
        currency: order.currency,
        orderId,
        paymentId,
        paidBy: userId,
      };
    }
    if (
      savedPayment?.paidBy === userId &&
      savedPayment?.paymentId === paymentId
    ) {
      return {
        verified: true,
        amount: order.amount,
        currency: order.currency,
        orderId,
        paymentId,
        paidBy: userId,
      };
    }
    throw new HttpError(409, "A restaurant payment is already recorded.");
  }
  if (!groupDocument.updateTime) {
    throw new HttpError(502, "Firestore did not return the group update time.");
  }

  const paidAt = new Date();
  const amountInRupees = order.amount / 100;
  await updateFirestoreDocument(
    `/group_orders/${groupId}`,
    {
      paymentStatus: "paid",
      status: "restaurant_paid",
      restaurantTotal: amountInRupees,
      paidBy: userId,
      paymentId,
      paidAt,
      restaurantPayment: {
        paidBy: userId,
        status: "test_mode_verified",
        paymentId,
        orderId,
        amount: amountInRupees,
        paidAt,
        testMode: true,
      },
    },
    groupDocument.updateTime,
    token,
    env,
  );

  return {
    verified: true,
    amount: order.amount,
    currency: order.currency,
    orderId,
    paymentId,
    paidBy: userId,
  };
}
