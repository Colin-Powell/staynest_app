import re

with open('../backend/src/routes/properties.ts', 'r', encoding='utf-8') as f:
    content = f.read()

# Add sendPushToUser import
if "sendPushToUser" not in content:
    content = content.replace("import { env } from '../config.js';", "import { env } from '../config.js';\nimport { sendPushToUser } from '../services/firebase.js';")

# Add successful listing notification
target = """    // The listing remains pending-review until an admin approves it.
    // Do not surface it to tenants before approval.
    clearCachePattern('properties.');

    res.status(201).json({ data: result.rows[0] });"""

replacement = """    // The listing remains pending-review until an admin approves it.
    // Do not surface it to tenants before approval.
    clearCachePattern('properties.');

    const property = result.rows[0];

    // Notify the landlord that their listing was submitted
    await sendPushToUser(
      userId,
      'Listing Submitted ??',
      `Your property "${property.title}" has been successfully submitted and is pending admin review.`,
      { type: 'property_submitted', propertyId: property.id }
    );

    res.status(201).json({ data: property });"""

content = content.replace(target, replacement)

with open('../backend/src/routes/properties.ts', 'w', encoding='utf-8') as f:
    f.write(content)
print("Added successful listing notification")
