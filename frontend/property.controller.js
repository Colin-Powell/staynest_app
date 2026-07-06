const pool = require('../config/db'); // Assuming you have a db config using pg pool

exports.getNearbyProperties = async (req, res) => {
  try {
    const { lat, lng, radius = 50, type, minPrice, maxPrice } = req.query;

    if (!lat || !lng) {
      return res.status(400).json({ message: "User location (lat, lng) is required." });
    }

    // Haversine formula to calculate distance in KM
    // 6371 is the earth radius in KM
    let query = `
      SELECT *, 
      (6371 * acos(cos(radians($1)) * cos(radians(latitude)) * cos(radians(longitude) - radians($2)) + sin(radians($1)) * sin(radians(latitude)))) AS distance
      FROM properties
      WHERE 1=1
    `;
    
    const values = [lat, lng];
    let paramIndex = 3;

    // Add Filters
    if (type) {
      query += ` AND type = $${paramIndex++}`;
      values.push(type);
    }
    if (minPrice) {
      query += ` AND price >= $${paramIndex++}`;
      values.push(minPrice);
    }

    query += ` HAVING (6371 * acos(cos(radians($1)) * cos(radians(latitude)) * cos(radians(longitude) - radians($2)) + sin(radians($1)) * sin(radians(latitude)))) < $${paramIndex}`;
    values.push(radius);
    
    query += ` ORDER BY distance ASC`;

    const { rows } = await pool.query(query, values);
    res.json(rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};