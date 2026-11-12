const jwt = require("jsonwebtoken");

const JWT_SECRET = process.env.JWT_SECRET || "yummygo_default_jwt_secret_key";

/**
 * Middleware to authenticate requests using JWT Bearer token
 */
function authenticateToken(req, res, next) {
  const authHeader = req.headers["authorization"];
  const token = authHeader && authHeader.startsWith("Bearer ")
    ? authHeader.split(" ")[1]
    : null;

  if (!token) {
    return res.status(401).json({
      success: false,
      message: "Access denied. No authentication token provided.",
    });
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
    next();
  } catch (error) {
    return res.status(403).json({
      success: false,
      message: "Invalid or expired token.",
    });
  }
}

/**
 * Middleware to restrict access to specific roles (e.g. 'admin', 'restaurant_owner')
 */
function authorizeRoles(...allowedRoles) {
  return (req, res, next) => {
    if (!req.user || !allowedRoles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: "Forbidden: You do not have permission to access this resource.",
      });
    }
    next();
  };
}

module.exports = {
  authenticateToken,
  authorizeRoles,
};

