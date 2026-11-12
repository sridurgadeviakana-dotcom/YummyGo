const { initializeApp } = require("firebase/app");

const {
  getFirestore,
  connectFirestoreEmulator,
  doc,
  setDoc,
} = require("firebase/firestore");

const app = initializeApp({
  projectId: "yummygo-73dc0",
  apiKey: "demo-api-key",
});

const db = getFirestore(app);

connectFirestoreEmulator(db, "127.0.0.1", 8080);

const foodItems = [
  {
    id: "food_001",
    name: "Chicken Biryani",
    restaurantId: "paradise_madhapur",
    restaurant: "Paradise Biryani",
    category: "Biryanis",
    price: 250,
    image: "",
  },
  {
    id: "food_002",
    name: "Veg Biryani",
    restaurantId: "paradise_madhapur",
    restaurant: "Paradise Biryani",
    category: "Biryanis",
    price: 180,
    image: "",
  },
  {
    id: "food_003",
    name: "Chicken Pizza",
    restaurantId: "pizza_hut_hitech_city",
    restaurant: "Pizza Hut",
    category: "Pizzas",
    price: 300,
    image: "",
  },
  {
    id: "food_004",
    name: "Chicken Burger",
    restaurantId: "burger_king_kukatpally",
    restaurant: "Burger King",
    category: "Burgers",
    price: 150,
    image: "",
  },
  {
    id: "food_005",
    name: "Veg Pulao",
    restaurantId: "paradise_madhapur",
    restaurant: "Paradise Biryani",
    category: "Pulaos",
    price: 160,
    image: "",
  },
];

async function addFoodItems() {
  try {
    for (const food of foodItems) {
      await setDoc(doc(db, "food_items", food.id), {
        name: food.name,
        restaurantId: food.restaurantId,
        restaurant: food.restaurant,
        restaurantName: food.restaurant,
        category: food.category,
        price: food.price,
        image: food.image,
      });

      console.log(food.name + " added successfully");
    }

    console.log("All food items added successfully!");
  } catch (error) {
    console.error("Error:", error);
  }
}

addFoodItems();