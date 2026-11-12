
const { onCall, HttpsError } =
  require("firebase-functions/v2/https");

const { defineSecret } =
  require("firebase-functions/params");

const { initializeApp } =
  require("firebase-admin/app");

const { getFirestore } =
  require("firebase-admin/firestore");

const Razorpay = require("razorpay");
const crypto = require("crypto");

initializeApp();

const db = getFirestore();

function getTestModeRazorpay() {
  const keyId = RAZORPAY_KEY_ID.value();
  const keySecret = RAZORPAY_KEY_SECRET.value();
  if (!keyId.startsWith("rzp_test_")) {
    throw new HttpsError(
      "failed-precondition",
      "Razorpay is restricted to test mode. Configure test API credentials."
    );
  }
  return new Razorpay({ key_id: keyId, key_secret: keySecret });
}

// Read credentials securely
const RAZORPAY_KEY_ID =
  defineSecret("RAZORPAY_KEY_ID");

const RAZORPAY_KEY_SECRET =
  defineSecret("RAZORPAY_KEY_SECRET");

// Create Razorpay Order
exports.createRazorpayOrder = onCall(
  {
    secrets: [RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET]
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Please login first."
      );
    }

    const { groupId, expectedAmount } = request.data || {};
    if (
      typeof groupId !== "string" ||
      groupId.trim() === "" ||
      !Number.isSafeInteger(expectedAmount) ||
      expectedAmount <= 0
    ) {
      throw new HttpsError("invalid-argument", "Invalid payment request.");
    }

    try {
      const groupRef = db.collection("group_orders").doc(groupId);
      const groupSnapshot = await groupRef.get();
      if (!groupSnapshot.exists) {
        throw new HttpsError("not-found", "Group order not found.");
      }

      const memberSnapshot = await groupRef
        .collection("members")
        .doc(request.auth.uid)
        .get();
      if (!memberSnapshot.exists) {
        throw new HttpsError(
          "permission-denied",
          "You are not a member of this group."
        );
      }

      const cartSnapshot = await groupRef.collection("cart").get();
      if (cartSnapshot.empty) {
        throw new HttpsError("failed-precondition", "The group cart is empty.");
      }

      const itemAmounts = await Promise.all(
        cartSnapshot.docs.map(async (cartItem) => {
          const foodId = cartItem.data().foodId;
          const quantity = Number(cartItem.data().quantity ?? 1);
          if (
            typeof foodId !== "string" ||
            !Number.isInteger(quantity) ||
            quantity <= 0
          ) {
            throw new HttpsError(
              "failed-precondition",
              "A cart item is invalid. Remove it and add it again."
            );
          }

          const foodSnapshot = await db.collection("food_items").doc(foodId).get();
          if (!foodSnapshot.exists) {
            throw new HttpsError(
              "failed-precondition",
              "A food item is no longer available."
            );
          }

          const price = Number(foodSnapshot.data().price);
          if (!Number.isFinite(price) || price <= 0) {
            throw new HttpsError(
              "failed-precondition",
              "A food item has an invalid price."
            );
          }

          return Math.round(price * 100) * quantity;
        })
      );
      const amount = itemAmounts.reduce((sum, itemAmount) => sum + itemAmount, 0);

      if (!Number.isSafeInteger(amount) || amount <= 0) {
        throw new HttpsError("failed-precondition", "Invalid group cart total.");
      }
      if (expectedAmount !== amount) {
        throw new HttpsError(
          "failed-precondition",
          "The group cart changed. Review the total and try again."
        );
      }

      const razorpay = getTestModeRazorpay();

      const order = await razorpay.orders.create({
        amount: amount,
        currency: "INR",
        receipt: `yummy_${Date.now()}`
      });

      await db.collection("razorpay_orders")
        .doc(order.id)
        .set({
          orderId: order.id,
          groupId: groupId,
          userId: request.auth.uid,
          amount: amount,
          currency: "INR",
          status: "created",
          createdAt: new Date()
        });

      return {
        orderId: order.id,
        amount: order.amount,
        currency: order.currency,
        keyId: RAZORPAY_KEY_ID.value()
      };

    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("Order error:", error);

      throw new HttpsError(
        "internal",
        "Unable to create payment order."
      );
    }
  }
);

exports.verifyRazorpayPayment = onCall(
  {
    secrets: [RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET]
  },
  async (request) => {

    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Please login first."
      );
    }

    const {
      orderId,
      paymentId,
      signature
    } = request.data || {};

    if (
      typeof orderId !== "string" ||
      typeof paymentId !== "string" ||
      typeof signature !== "string" ||
      !/^[a-f0-9]{64}$/i.test(signature)
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Invalid payment details."
      );
    }

    const orderRef = db.collection("razorpay_orders").doc(orderId);
    const orderDoc = await orderRef.get();
    const orderData = orderDoc.data();

    if (
      !orderDoc.exists ||
      orderData.userId !== request.auth.uid
    ) {
      throw new HttpsError(
        "permission-denied",
        "Order not found."
      );
    }

    if (orderData.status === "verified") {
      if (orderData.paymentId !== paymentId) {
        throw new HttpsError("already-exists", "This order was already paid.");
      }
      return { verified: true, paymentId: paymentId };
    }

    const razorpay = getTestModeRazorpay();
    const expectedSignature = crypto
      .createHmac(
        "sha256",
        RAZORPAY_KEY_SECRET.value()
      )
      .update(`${orderId}|${paymentId}`)
      .digest("hex");

    const isValid = crypto.timingSafeEqual(
      Buffer.from(signature, "hex"),
      Buffer.from(expectedSignature, "hex")
    );

    if (!isValid) {
      throw new HttpsError(
        "permission-denied",
        "Payment signature is invalid."
      );
    }

    let payment = await razorpay.payments.fetch(paymentId);

    if (
      payment.order_id !== orderId ||
      payment.amount !== orderData.amount ||
      payment.currency !== orderData.currency
    ) {
      throw new HttpsError("permission-denied", "Payment details do not match.");
    }

    if (payment.status === "authorized") {
      payment = await razorpay.payments.capture(
        paymentId,
        orderData.amount,
        orderData.currency
      );
    }
    if (payment.status !== "captured") {
      throw new HttpsError("failed-precondition", "Payment is not captured.");
    }

    await db.runTransaction(async (transaction) => {
      const currentOrder = await transaction.get(orderRef);
      const currentData = currentOrder.data();
      if (!currentOrder.exists || currentData.userId !== request.auth.uid) {
        throw new HttpsError("permission-denied", "Order not found.");
      }
      if (currentData.status === "verified") {
        if (currentData.paymentId !== paymentId) {
          throw new HttpsError("already-exists", "This order was already paid.");
        }
        return;
      }

      transaction.update(orderRef, {
        status: "verified",
        paymentId: paymentId,
        verifiedAt: new Date()
      });
      transaction.update(db.collection("group_orders").doc(currentData.groupId), {
        paymentStatus: "paid",
        paymentId: paymentId,
        paidAt: new Date()
      });
    });

    return {
      verified: true,
      paymentId: paymentId
    };
  }
);
