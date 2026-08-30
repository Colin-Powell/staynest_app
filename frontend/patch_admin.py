import re

with open('../backend/src/routes/admin.ts', 'r', encoding='utf-8') as f:
    content = f.read()

# Add imports
if "clearCachePattern" not in content:
    content = content.replace("import { env } from '../config.js';", "import { env } from '../config.js';\nimport { clearCachePattern } from '../services/cache.js';\nimport { sendPushToUser } from '../services/firebase.js';")

# Fix PATCH properties/:id/status
target = """    const updateRes = await query(`
      UPDATE properties
      SET status = $1
      WHERE id = $2
      RETURNING *
    `, [status, id]);

    if (updateRes.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Property not found'
      });
    }

    res.json({
      success: true,
      data: updateRes.rows[0]
    });"""

replacement = """    const updateRes = await query(`
      UPDATE properties
      SET status = $1
      WHERE id = $2
      RETURNING *
    `, [status, id]);

    if (updateRes.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Property not found'
      });
    }

    const property = updateRes.rows[0];

    // Clear property cache since visibility changed
    await clearCachePattern('properties');

    // Notify the landlord
    if (status === 'approved') {
      await sendPushToUser(
        property.landlord_id,
        'Property Approved! ??',
        `Your listing "${property.title}" has been approved and is now live on StayNest.`,
        { type: 'property_status', propertyId: id, status: 'approved' }
      );
    } else if (status === 'rejected') {
      await sendPushToUser(
        property.landlord_id,
        'Property Requires Revision',
        `Your listing "${property.title}" requires some changes before it can be published.`,
        { type: 'property_status', propertyId: id, status: 'rejected' }
      );
    }

    res.json({
      success: true,
      data: property
    });"""

content = content.replace(target, replacement)

with open('../backend/src/routes/admin.ts', 'w', encoding='utf-8') as f:
    f.write(content)
print("Patched admin.ts to notify landlord and clear cache")
