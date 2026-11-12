
const fs = require("fs");
const path = require("path");

const { cert, initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

const serviceAccount = require("./serviceAccountKey.json");
const projectId = "yummygo-73dc0";
const syncMenuImages = process.env.SYNC_MENU_IMAGES === "true";
const syncMenuDescriptions = process.env.SYNC_MENU_DESCRIPTIONS === "true";

initializeApp({
  credential: cert(serviceAccount),
  projectId,
});

const db = getFirestore();

const paradiseItems = JSON.parse(
  fs.readFileSync(
    path.resolve(__dirname, "../assets/data/yummygo_menu_items.json"),
    "utf8"
  )
);

function item(id, name, category, price, image, options = {}) {
  return {
    id,
    name,
    category,
    price,
    rating: options.rating || 4.2,
    time: options.time || "20-30 min",
    image,
    tag: options.tag || "",
    isVeg: options.isVeg ?? true,
    isEatRight: options.isEatRight ?? false,
    isRepeat: options.isRepeat ?? false,
    isBestSeller: options.isBestSeller ?? false,
    isFeatured: options.isFeatured ?? false,
  };
}

const menus = {
  pizza_hut_hitech_city: [
    item("margherita_pizza", "Margherita Pizza", "Pizzas", 199,
      "https://images.unsplash.com/photo-1579751626657-72bc17010498?w=800", { isBestSeller: true, isFeatured: true }),
    item("farmhouse_pizza", "Farmhouse Pizza", "Pizzas", 349,
      "https://images.unsplash.com/photo-1513104890138-7c749659a591?w=800", { isBestSeller: true, isVeg: true }),
    item("paneer_tikka_pizza", "Paneer Tikka Pizza", "Pizzas", 329,
      "https://images.unsplash.com/photo-1579751626657-72bc17010498?w=800"),
    item("garlic_bread", "Garlic Bread", "Sides", 129,
      "https://images.unsplash.com/photo-1619531040576-f94167406613?w=800"),
  ],

  burger_king_kukatpally: [
    item("whopper", "Veg Whopper", "Burgers", 179,
      "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800", { isBestSeller: true, isFeatured: true }),
    item("crispy_chicken_burger", "Crispy Chicken Burger", "Burgers", 199,
      "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800", { isVeg: false, isBestSeller: true }),
    item("classic_fries", "Classic Fries", "Sides", 99,
      "https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=800"),
    item("cheese_burger", "Cheese Burger", "Burgers", 149,
      "https://images.unsplash.com/photo-1550547660-d9450f859349?w=800"),
  ],

  dominos_kondapur: [
    item("cheese_burst_pizza", "Cheese Burst Pizza", "Pizzas", 299,
      "https://images.unsplash.com/photo-1513104890138-7c749659a591?w=800", { isBestSeller: true, isFeatured: true }),
    item("pepperoni_pizza", "Pepperoni Pizza", "Pizzas", 399,
      "https://images.unsplash.com/photo-1579751626657-72bc17010498?w=800", { isVeg: false }),
    item("white_sauce_pasta", "White Sauce Pasta", "Pasta", 179,
      "https://images.unsplash.com/photo-1473093295043-cdd812d0e601?w=800"),
    item("choco_lava_cake", "Choco Lava Cake", "Desserts", 109,
      "https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=800"),
  ],

  kfc_gachibowli: [
    item("hot_wings", "Hot Wings", "Chicken", 199,
      "https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=800", { isVeg: false, isBestSeller: true, isFeatured: true }),
    item("crispy_fried_chicken", "Crispy Fried Chicken", "Chicken", 249,
      "https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=800", { isVeg: false, isBestSeller: true }),
    item("chicken_popcorn", "Chicken Popcorn", "Starters", 149,
      "https://images.unsplash.com/photo-1562967914-608f82629710?w=800", { isVeg: false }),
    item("chicken_burger", "Chicken Burger", "Burgers", 179,
      "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800", { isVeg: false }),
  ],

  subway_miyapur: [
    item("veg_sub", "Veggie Delight Sub", "Subs", 179,
      "https://images.unsplash.com/photo-1553909489-cd47e0ef937f?w=800", { isBestSeller: true, isFeatured: true }),
    item("chicken_sub", "Chicken Tikka Sub", "Subs", 229,
      "https://images.unsplash.com/photo-1553909489-cd47e0ef937f?w=800", { isVeg: false }),
    item("paneer_sub", "Paneer Tikka Sub", "Subs", 199,
      "https://images.unsplash.com/photo-1553909489-cd47e0ef937f?w=800"),
    item("corn_salad", "Corn Salad", "Salads", 129,
      "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800", { isEatRight: true }),
  ],

  chaat_corner_begumpet: [
    item("pani_puri", "Pani Puri", "Chaat", 60,
      "https://images.unsplash.com/photo-1601050690597-df0568f70950?w=800", { isBestSeller: true, isFeatured: true }),
    item("dahi_puri", "Dahi Puri", "Chaat", 90,
      "https://images.unsplash.com/photo-1601050690597-df0568f70950?w=800", { isBestSeller: true }),
    item("samosa_chaat", "Samosa Chaat", "Chaat", 100,
      "https://images.unsplash.com/photo-1601050690597-df0568f70950?w=800"),
    item("aloo_tikki", "Aloo Tikki", "Snacks", 80,
      "https://images.unsplash.com/photo-1601050690597-df0568f70950?w=800"),
  ],

  tandoori_nights_banjara_hills: [
    item("paneer_tikka", "Paneer Tikka", "Starters", 249,
      "https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=800", { isBestSeller: true, isFeatured: true }),
    item("tandoori_chicken", "Tandoori Chicken", "Starters", 349,
      "https://images.unsplash.com/photo-1544025162-d76694265947?w=800", { isVeg: false, isBestSeller: true }),
    item("chicken_tikka", "Chicken Tikka", "Starters", 299,
      "https://images.unsplash.com/photo-1544025162-d76694265947?w=800", { isVeg: false }),
    item("garlic_naan", "Garlic Naan", "Breads", 79,
      "https://images.unsplash.com/photo-1473093295043-cdd812d0e601?w=800"),
  ],

  green_bowl_jubilee_hills: [
    item("greek_salad", "Greek Salad", "Salads", 199,
      "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800", { isEatRight: true, isBestSeller: true, isFeatured: true }),
    item("protein_bowl", "Protein Power Bowl", "Healthy Bowls", 249,
      "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800", { isEatRight: true }),
    item("quinoa_bowl", "Quinoa Veg Bowl", "Healthy Bowls", 229,
      "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800", { isEatRight: true }),
    item("fruit_smoothie", "Fresh Fruit Smoothie", "Drinks", 149,
      "https://images.unsplash.com/photo-1505252585461-04db1eb84625?w=800", { isEatRight: true }),
  ],

  sweet_truth_secunderabad: [
    item("chocolate_brownie", "Chocolate Brownie", "Brownies", 129,
      "https://images.unsplash.com/photo-1606313564200-e75d5e30476c?w=800", { isBestSeller: true, isFeatured: true }),
    item("chocolate_cake", "Chocolate Truffle Cake", "Cakes", 249,
      "https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=800", { isBestSeller: true }),
    item("red_velvet_pastry", "Red Velvet Pastry", "Pastries", 119,
      "https://images.unsplash.com/photo-1586788680434-30d324b2d46f?w=800"),
    item("cheesecake", "Blueberry Cheesecake", "Cakes", 199,
      "https://images.unsplash.com/photo-1533134242443-d4fd215305ad?w=800"),
  ],


    chutneys_hitech_city: [
    item(
      "masala_dosa",
      "Masala Dosa",
      "South Indian",
      149,
      "https://images.unsplash.com/photo-1668236543090-82eba5ee5976?w=800",
      { isBestSeller: true, isFeatured: true }
    ),
    item(
      "idli_sambar",
      "Idli Sambar",
      "South Indian",
      99,
      "https://images.unsplash.com/photo-1589301760014-d929f3979dbc?w=800",
      { isBestSeller: true }
    ),
    item(
      "medu_vada",
      "Medu Vada",
      "South Indian",
      109,
      "https://images.unsplash.com/photo-1601050690117-94f5f6fa8bd7?w=800"
    ),
    item(
      "paneer_dosa",
      "Paneer Dosa",
      "South Indian",
      179,
      "https://images.unsplash.com/photo-1668236543090-82eba5ee5976?w=800"
    ),
  ],

  farzi_cafe_hitech_city: [
    item(
      "chicken_tikka",
      "Chicken Tikka",
      "Starters",
      329,
      "https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?w=800",
      { isVeg: false, isBestSeller: true, isFeatured: true }
    ),
    item(
      "dal_makhani",
      "Dal Makhani",
      "Main Course",
      269,
      "https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=800"
    ),
    item(
      "butter_chicken",
      "Butter Chicken",
      "Main Course",
      349,
      "https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?w=800",
      { isVeg: false, isBestSeller: true }
    ),
    item(
      "chicken_biryani",
      "Chicken Biryani",
      "Biryani",
      329,
      "https://images.unsplash.com/photo-1563379091339-03246963d96c?w=800",
      { isVeg: false, isBestSeller: true }
    ),
  ],

  exotica_hitech_city: [
    item(
      "paneer_tikka",
      "Paneer Tikka",
      "Starters",
      279,
      "https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=800",
      { isBestSeller: true, isFeatured: true }
    ),
    item(
      "chicken_biryani",
      "Chicken Biryani",
      "Biryani",
      299,
      "https://images.unsplash.com/photo-1563379091339-03246963d96c?w=800",
      { isVeg: false, isBestSeller: true }
    ),
    item(
      "butter_naan",
      "Butter Naan",
      "Breads",
      69,
      "https://images.unsplash.com/photo-1601050690597-df0568f70950?w=800"
    ),
    item(
      "dal_makhani",
      "Dal Makhani",
      "Main Course",
      229,
      "https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=800"
    ),
  ],

  absolute_barbecues_hitech_city: [
    item(
      "tandoori_chicken",
      "Tandoori Chicken",
      "Barbecue",
      349,
      "https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?w=800",
      { isVeg: false, isBestSeller: true, isFeatured: true }
    ),
    item(
      "paneer_tikka",
      "Paneer Tikka",
      "Barbecue",
      279,
      "https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=800",
      { isBestSeller: true }
    ),
    item(
      "bbq_chicken_wings",
      "BBQ Chicken Wings",
      "Barbecue",
      299,
      "https://images.unsplash.com/photo-1527477396000-e27163b481c2?w=800",
      { isVeg: false }
    ),
    item(
      "gulab_jamun",
      "Gulab Jamun",
      "Desserts",
      99,
      "https://images.unsplash.com/photo-1601303516534-9d9b1c7d2f8f?w=800"
    ),
  ],

  flechazo_hitech_city: [
    item(
      "paneer_tikka",
      "Paneer Tikka",
      "Starters",
      259,
      "https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=800",
      { isBestSeller: true, isFeatured: true }
    ),
    item(
      "chicken_tikka",
      "Chicken Tikka",
      "Starters",
      299,
      "https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?w=800",
      { isVeg: false, isBestSeller: true }
    ),
    item(
      "veg_biryani",
      "Veg Biryani",
      "Biryani",
      249,
      "https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=800"
    ),
    item(
      "chocolate_brownie",
      "Chocolate Brownie",
      "Desserts",
      149,
      "https://images.unsplash.com/photo-1606313564200-e75d5e30476c?w=800"
    ),
  ],

  karachi_bakery_hitech_city: [
    item(
      "fruit_biscuit",
      "Fruit Biscuit",
      "Biscuits",
      180,
      "https://images.unsplash.com/photo-1558961363-fa8fdf82db35?w=800",
      { isBestSeller: true, isFeatured: true }
    ),
    item(
      "chocolate_cake",
      "Chocolate Cake",
      "Cakes",
      499,
      "https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=800",
      { isBestSeller: true }
    ),
    item(
      "pineapple_cake",
      "Pineapple Cake",
      "Cakes",
      449,
      "https://images.unsplash.com/photo-1565958011703-44f9829ba187?w=800"
    ),
    item(
      "osmania_biscuit",
      "Osmania Biscuit",
      "Biscuits",
      160,
      "https://images.unsplash.com/photo-1558961363-fa8fdf82db35?w=800"
    ),
  ],

  mandi_36_hitech_city: [
    item(
      "chicken_mandi",
      "Chicken Mandi",
      "Mandi",
      399,
      "https://images.unsplash.com/photo-1563379091339-03246963d96c?w=800",
      { isVeg: false, isBestSeller: true, isFeatured: true }
    ),
    item(
      "mutton_mandi",
      "Mutton Mandi",
      "Mandi",
      499,
      "https://images.unsplash.com/photo-1544025162-d76694265947?w=800",
      { isVeg: false, isBestSeller: true }
    ),
    item(
      "chicken_shawarma",
      "Chicken Shawarma",
      "Arabian",
      199,
      "https://images.unsplash.com/photo-1529006557810-274b9b2fc783?w=800",
      { isVeg: false }
    ),
    item(
      "kunafa",
      "Kunafa",
      "Desserts",
      179,
      "https://images.unsplash.com/photo-1571115177098-24ec42ed204d?w=800"
    ),
  ],

  pakka_local_hitech_city: [
    item(
      "masala_dosa",
      "Masala Dosa",
      "South Indian",
      129,
      "https://images.unsplash.com/photo-1668236543090-82eba5ee5976?w=800",
      { isBestSeller: true, isFeatured: true }
    ),
    item(
      "paneer_65",
      "Paneer 65",
      "Starters",
      199,
      "https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=800"
    ),
    item(
      "chicken_biryani",
      "Chicken Biryani",
      "Biryani",
      249,
      "https://images.unsplash.com/photo-1563379091339-03246963d96c?w=800",
      { isVeg: false, isBestSeller: true }
    ),
    item(
      "parotta",
      "Kerala Parotta",
      "Breads",
      89,
      "https://images.unsplash.com/photo-1601050690597-df0568f70950?w=800"
    ),
  ],

  southern_spice_hitech_city: [
    item(
      "idli",
      "Idli",
      "South Indian",
      89,
      "https://images.unsplash.com/photo-1589301760014-d929f3979dbc?w=800",
      { isBestSeller: true, isFeatured: true }
    ),
    item(
      "ghee_roast_dosa",
      "Ghee Roast Dosa",
      "South Indian",
      159,
      "https://images.unsplash.com/photo-1668236543090-82eba5ee5976?w=800",
      { isBestSeller: true }
    ),
    item(
      "paneer_butter_masala",
      "Paneer Butter Masala",
      "Main Course",
      249,
      "https://images.unsplash.com/photo-1601050690117-94f5f6fa8bd7?w=800"
    ),
    item(
      "andhra_meals",
      "Andhra Meals",
      "Meals",
      199,
      "https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=800"
    ),
  ],

  the_fishermans_wharf_hitech_city: [
    item(
      "fish_curry",
      "Fish Curry",
      "Seafood",
      329,
      "https://images.unsplash.com/photo-1534766555764-ce878a5e3a2b?w=800",
      { isVeg: false, isBestSeller: true, isFeatured: true }
    ),
    item(
      "prawn_fry",
      "Prawn Fry",
      "Seafood",
      399,
      "https://images.unsplash.com/photo-1559339352-11d035aa65de?w=800",
      { isVeg: false, isBestSeller: true }
    ),
    item(
      "fish_and_chips",
      "Fish and Chips",
      "Seafood",
      349,
      "https://images.unsplash.com/photo-1579208030886-b937da0925dc?w=800",
      { isVeg: false }
    ),
    item(
      "chicken_cafreal",
      "Chicken Cafreal",
      "Goan",
      329,
      "https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?w=800",
      { isVeg: false }
    ),
  ],
};

async function seedRestaurantMenu(restaurantId, items) {
  const restaurantRef = db.collection("restaurants").doc(restaurantId);
  const restaurantDoc = await restaurantRef.get();

  if (!restaurantDoc.exists) {
    throw new Error(`Restaurant not found: ${restaurantId}`);
  }

  const restaurantName = restaurantDoc.data().name;
  let created = 0;
  let imagesUpdated = 0;
  let skipped = 0;

  for (const menuItem of items) {
    const docId = `${restaurantId}_${menuItem.id}`;
    const itemRef = db.collection("food_items").doc(docId);
    const existing = await itemRef.get();

    if (existing.exists) {
      const updates = {};
      if (
        syncMenuImages &&
        typeof menuItem.image === "string" &&
        menuItem.image.trim() !== "" &&
        existing.data().image !== menuItem.image
      ) {
        updates.image = menuItem.image;
      }
      if (
        syncMenuDescriptions &&
        typeof menuItem.description === "string" &&
        menuItem.description.trim() !== "" &&
        existing.data().description !== menuItem.description
      ) {
        updates.description = menuItem.description;
      }
      if (Object.keys(updates).length > 0) {
        await itemRef.update(updates);
        if (updates.image) imagesUpdated++;
        continue;
      }

      skipped++;
      continue;
    }

    await itemRef.set({
      ...menuItem,
      restaurantId,
      restaurant: restaurantName,
      restaurantName,
    });

    created++;
  }

  console.log(
    `${restaurantName}: ${created} created, ${imagesUpdated} images updated, ` +
      `${skipped} already present`
  );
}

async function main() {
  // Preserve and seed the existing Paradise menu.
  await seedRestaurantMenu("paradise_madhapur", paradiseItems);

  // Seed unique menus for the remaining restaurants.
  for (const [restaurantId, items] of Object.entries(menus)) {
    await seedRestaurantMenu(restaurantId, items);
  }

  console.log("All restaurant menus seeded successfully!");
}

main().catch((error) => {
  console.error("Menu seeding failed:", error);
  process.exitCode = 1;
});
