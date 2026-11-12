const fs = require("fs");
const path = require("path");

const { cert, initializeApp } = require("firebase-admin/app");
const serviceAccount = require("./serviceAccountKey.json");
const { getFirestore } = require("firebase-admin/firestore");

const projectId = "yummygo-73dc0";
const restaurantFile = path.resolve(
  __dirname,
  "../assets/data/yummygo_restaurants.json"
);
const restaurants = JSON.parse(fs.readFileSync(restaurantFile, "utf8"));

initializeApp({
  credential: cert(serviceAccount),
  projectId,
});

async function seedRestaurants() {
  const db = getFirestore();
  const collection = db.collection("restaurants");
  const existingSnapshot = await collection.get();
  const existingNames = new Set(
    existingSnapshot.docs
      .map((doc) => doc.data().name)
      .filter((name) => typeof name === "string")
      .map((name) => name.trim().toLowerCase())
  );
  const batch = db.batch();
  let created = 0;
  let imagesUpdated = 0;
  let skipped = 0;

  for (const restaurant of restaurants) {
    if (
      typeof restaurant.id !== "string" ||
      restaurant.id.trim() === "" ||
      typeof restaurant.name !== "string" ||
      restaurant.name.trim() === ""
    ) {
      throw new Error("Every restaurant must have a non-empty id and name.");
    }

    const restaurantRef = collection.doc(restaurant.id);
    const existingDocument = existingSnapshot.docs.some(
      (doc) => doc.id === restaurant.id
    );
    const duplicateName = existingNames.has(
      restaurant.name.trim().toLowerCase()
    );

    if (existingDocument) {
      const existing = existingSnapshot.docs.find(
        (doc) => doc.id === restaurant.id
      );
      if (
        typeof restaurant.imageUrl === "string" &&
        restaurant.imageUrl.trim() !== "" &&
        existing.data().imageUrl !== restaurant.imageUrl
      ) {
        batch.update(existing.ref, { imageUrl: restaurant.imageUrl });
        imagesUpdated++;
      } else {
        skipped++;
      }
      continue;
    }

    if (duplicateName) {
      skipped++;
      continue;
    }

    batch.create(restaurantRef, restaurant);
    existingNames.add(restaurant.name.trim().toLowerCase());
    created++;
  }

  if (created + imagesUpdated > 0) {
    await batch.commit();
  }

  console.log(
    `Firestore restaurants seed complete: ${created} created, ` +
      `${imagesUpdated} images updated, ${skipped} already present.`
  );
}

seedRestaurants().catch((error) => {
  console.error("Unable to seed restaurants:", error.message);
  process.exitCode = 1;
});
