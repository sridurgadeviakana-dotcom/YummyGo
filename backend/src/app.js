const express = require("express");
const prisma = require("./config/prisma");

const app = express();

app.use(express.json());

// Home API
app.get("/", (req, res) => {
  res.status(200).json({
    success: true,
    message: "Welcome to YummyGo Backend API",
  });
});

// PostgreSQL connection test API
app.get("/test-db", async (req, res) => {
  try {
    await prisma.$connect();

    res.status(200).json({
      success: true,
      message: "PostgreSQL connected successfully!",
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Database connection failed",
      error: error.message,
    });
  }
});

module.exports = app;