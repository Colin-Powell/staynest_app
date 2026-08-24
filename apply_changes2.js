const fs = require('fs');

function replace(path, search, replaceStr) {
  let content = fs.readFileSync(path, 'utf8');
  if (typeof search === 'string') {
    content = content.replace(search, replaceStr);
  } else {
    content = content.replace(search, replaceStr);
  }
  fs.writeFileSync(path, content, 'utf8');
  console.log(`Updated ${path}`);
}

// 2. messages.ts
replace('backend/src/routes/messages.ts',
  /ioInstance\.to\(`user:\$\{to_user_id\}`\)\.emit\('message', payload\);\n    }/,
  `ioInstance.to(\`user:\${to_user_id}\`).emit('message', payload);
    }
    if (to_user_id !== from_user_id) {
      try {
        const senderRes = await query('SELECT name FROM users WHERE id = $1 LIMIT 1', [from_user_id]);
        const senderName = senderRes.rowCount > 0 ? senderRes.rows[0].name : 'Someone';
        const shortText = text.length > 60 ? text.substring(0, 57) + '...' : text;
        await sendPushToUser(to_user_id, senderName, shortText, { type: 'chat_message', from_user_id });
      } catch (e) { console.error('Push error:', e); }
    }`
);

// 3. verifications.ts
replace('backend/src/routes/verifications.ts',
  /if \(status === 'approved'\) \{\n      await query\(`UPDATE users SET verified = true WHERE id = \$1`, \[result\.rows\[0\]\.user_id\]\);\n    }/,
  `if (status === 'approved') {
      await query(\`UPDATE users SET verified = true WHERE id = $1\`, [result.rows[0].user_id]);
      await sendPushToUser(result.rows[0].user_id, '? Verification Approved', 'Your landlord verification was approved! You can now list properties.', { type: 'verification_approved' });
    } else if (status === 'rejected') {
      await sendPushToUser(result.rows[0].user_id, '? Verification Rejected', 'Your landlord verification was rejected. Please check the notes.', { type: 'verification_rejected' });
    }`
);

// 4. bookings.ts
replace('backend/src/routes/bookings.ts',
  /bookingData = bookingResult\.rows\[0\];\n      await query\('COMMIT'\);/,
  `bookingData = bookingResult.rows[0];
      await query('COMMIT');
      
      try {
        const tenantRes = await query('SELECT name FROM users WHERE id = $1 LIMIT 1', [req.auth!.id]);
        const pRes = await query('SELECT title FROM properties WHERE id = $1 LIMIT 1', [propertyId]);
        const tenantName = tenantRes.rows[0]?.name || 'A tenant';
        const pName = pRes.rows[0]?.title || 'your property';
        await sendPushToUser(landlordId, '?? New Booking Request', \`\${tenantName} requested to book \${pName}.\`, { type: 'new_booking', bookingId: bookingData.id });
      } catch(e) { console.error('Push error:', e); }`
);
replace('backend/src/routes/bookings.ts',
  /\['confirmed', bookingId\],\n    \);\n\n    res\.json\(\{ data: result\.rows\[0\] \}\);/,
  `['confirmed', bookingId],
    );
    try {
      const b = result.rows[0];
      const pRes = await query('SELECT title FROM properties WHERE id = $1 LIMIT 1', [b.property_id]);
      const pName = pRes.rows[0]?.title || 'a property';
      await sendPushToUser(b.tenant_id, '? Booking Approved', \`Your booking for \${pName} was approved!\`, { type: 'booking_approved', bookingId });
    } catch(e) { console.error('Push error:', e); }
    res.json({ data: result.rows[0] });`
);
replace('backend/src/routes/bookings.ts',
  /\['rejected', notesUpdate, bookingId\],\n    \);\n\n    res\.json\(\{ data: result\.rows\[0\] \}\);/,
  `['rejected', notesUpdate, bookingId],
    );
    try {
      const b = result.rows[0];
      const pRes = await query('SELECT title FROM properties WHERE id = $1 LIMIT 1', [b.property_id]);
      const pName = pRes.rows[0]?.title || 'a property';
      await sendPushToUser(b.tenant_id, '? Booking Declined', \`Your booking for \${pName} was declined.\`, { type: 'booking_declined', bookingId });
    } catch(e) { console.error('Push error:', e); }
    res.json({ data: result.rows[0] });`
);
replace('backend/src/routes/bookings.ts',
  /\['cancelled', notesUpdate, bookingId\],\n    \);\n\n    res\.json\(\{ data: result\.rows\[0\] \}\);/,
  `['cancelled', notesUpdate, bookingId],
    );
    try {
      const b = result.rows[0];
      const notifyUserId = isTenant ? b.landlord_id : b.tenant_id;
      const actor = isTenant ? 'Tenant' : 'Landlord';
      const pRes = await query('SELECT title FROM properties WHERE id = $1 LIMIT 1', [b.property_id]);
      const pName = pRes.rows[0]?.title || 'a property';
      await sendPushToUser(notifyUserId, '?? Booking Cancelled', \`\${actor} cancelled the booking for \${pName}.\`, { type: 'booking_cancelled', bookingId });
    } catch(e) { console.error('Push error:', e); }
    res.json({ data: result.rows[0] });`
);
