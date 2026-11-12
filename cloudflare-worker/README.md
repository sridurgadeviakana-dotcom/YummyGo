# YummyGo Razorpay test Worker

This Worker creates Razorpay orders from the current Firestore group cart,
verifies Razorpay's payment signature and captured payment, and records the
restaurant payer in Firestore. It rejects live Razorpay keys. It uses
Cloudflare Workers rather than Firebase Cloud Functions.

This is for test-mode integration only. Firestore split data is still written
by the signed-in Flutter client, so deploy appropriate Firestore Security Rules
before using this design with real money. Cloudflare and Razorpay free/test
limits and account requirements apply.

## Configure and deploy

1. Install Node.js and sign in to Wrangler:

   ```powershell
   npx wrangler login
   ```

2. From the repository root, set your Razorpay **Test Mode** credentials.
   Set the Firebase service-account JSON as a Worker secret as well. Wrangler
   prompts for each value; do not commit these secrets or put them in Flutter:

   ```powershell
   npx wrangler secret put RAZORPAY_KEY_ID --config cloudflare-worker/wrangler.toml
   npx wrangler secret put RAZORPAY_KEY_SECRET --config cloudflare-worker/wrangler.toml
   npx wrangler secret put FIREBASE_SERVICE_ACCOUNT --config cloudflare-worker/wrangler.toml
   ```

   For the last command, paste the complete Firebase service-account JSON when
   prompted. The service account needs Firestore access in project
   `yummygo-73dc0`. The key ID must start with `rzp_test_`.

3. Deploy the Worker:

   ```powershell
   npx wrangler deploy --config cloudflare-worker/wrangler.toml
   ```

4. Flutter is configured to use the current Worker URL by default. To override
   it for another environment, run:

   ```powershell
   flutter run --dart-define=RAZORPAY_WORKER_URL=https://YOUR-WORKER.YOUR-SUBDOMAIN.workers.dev
   ```

The Worker URL is public configuration, not a secret. The Razorpay secret stays
in Cloudflare. The Worker validates Firebase ID tokens, checks group membership,
uses the service account to access Firestore, calculates the cart amount from
Firestore menu prices, creates a Razorpay order without a Firestore transaction,
and verifies the returned signature and captured payment. It saves the verified
payer using a Firestore update-time precondition. The app calls
`POST /create-order` and `POST /verify-payment` with the Firebase ID token in
the Authorization header.

The Worker accepts either the `FIREBASE_SERVICE_ACCOUNT` secret name or the
older `FIREBASE_SERVICE_ACCOUNT_JSON` name.

Use Razorpay's test payment credentials/card details from the Razorpay
Dashboard. Test payments do not transfer real money.
