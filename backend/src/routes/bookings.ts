import { Router, Request, Response, NextFunction } from 'express';
import { pool, query } from '../db.js';
import { authorize, requireAuth } from '../middleware/auth.js';
import { queueUserPush } from '../services/queue.js';
import { settleReferralReward } from '../services/referral_service.js';
import {
  BOOKING_VIEWING_FEE_KES,
  completeBookingWithEscrow,
  createAndPayBookingFromWallet,
  refundExpiredBookingEscrows,
  settleEscrow,
} from '../services/finance_service.js';

const router = Router();
const unavailablePropertyStatuses = new Set([
  'fully_booked',
  'unavailable',
  'rented',
  'maintenance',
]);

function isPropertyUnavailable(availabilityStatus: unknown, legacyStatus: unknown): boolean {
  const availability = String(availabilityStatus ?? '').toLowerCase();
  const legacy = String(legacyStatus ?? '').toLowerCase();
  return unavailablePropertyStatuses.has(availability) ||
    (['', 'unknown'].includes(availability) && unavailablePropertyStatuses.has(legacy));
}

router.post('/pay-with-wallet', requireAuth, authorize('tenant'), async (req: Request, res: Response, next: NextFunction) => {
  const { propertyId, checkInDate, checkOutDate, notes } = req.body as {
    propertyId?: string;
    checkInDate?: string;
    checkOutDate?: string;
    notes?: string;
  };
  const idempotencyKey = String(req.get('Idempotency-Key') ?? '').trim();

  if (!propertyId || !checkInDate || !checkOutDate || !idempotencyKey) {
    return res.status(400).json({
      error: 'propertyId, checkInDate, checkOutDate, and Idempotency-Key are required.',
    });
  }

  try {
    const result = await createAndPayBookingFromWallet({
      propertyId,
      tenantId: req.auth!.id,
      checkInDate,
      checkOutDate,
      notes,
      idempotencyKey,
    });

    if (result.created) {
      try {
        const tenantResult = await query(
          'SELECT name FROM users WHERE id = $1 LIMIT 1',
          [req.auth!.id],
        );
        const propertyResult = await query(
          'SELECT title FROM properties WHERE id = $1 LIMIT 1',
          [propertyId],
        );
        await queueUserPush(
          String(result.booking.landlord_id),
          'New Booking Request',
          `${tenantResult.rows[0]?.name || 'A tenant'} paid to book ${propertyResult.rows[0]?.title || 'your property'}.`,
          { type: 'new_booking', bookingId: String(result.booking.id) },
        );
      } catch (pushError) {
        console.error('Paid booking notification error:', pushError);
      }
    }

    return res.status(result.created ? 201 : 200).json({
      data: {
        ...result.booking,
        escrow_id: result.escrowId,
        amount_paid: result.amount,
      },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Payment failed.';
    if (message.includes('Insufficient wallet balance')) {
      return res.status(402).json({ error: message });
    }
    if (message.includes('already booked') || message.includes('active booking') || message.includes('not available')) {
      return res.status(409).json({ error: message });
    }
    if (message.includes('Invalid booking date') || message.includes('total is invalid')) {
      return res.status(400).json({ error: message });
    }
    if (message.includes('Property not found')) {
      return res.status(404).json({ error: message });
    }
    if (message.includes('no landlord') || message.includes('own property')) {
      return res.status(400).json({ error: message });
    }
    return next(error);
  }
});

// Create a new booking (tenant creates booking)
router.post('/', requireAuth, authorize('tenant'), async (req: Request, res: Response, next: NextFunction) => {
  let client;
  try {
    client = await pool.connect();
    const { propertyId, checkInDate, checkOutDate, notes } = req.body as {
      propertyId?: string;
      checkInDate?: string;
      checkOutDate?: string;
      notes?: string;
    };

    if (!propertyId || !checkInDate || !checkOutDate) {
      return res.status(400).json({
        error: 'propertyId, checkInDate, and checkOutDate are required.',
      });
    }

    let bookingData;
    await client.query('BEGIN');
    try {
      // Lock the property row to prevent concurrent booking races
      const propResult = await client.query(
        'SELECT id, landlord_id, price, status, availability_status FROM properties WHERE id = $1 FOR UPDATE',
        [propertyId],
      );

      if (propResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Property not found.' });
      }

      const landlordId = propResult.rows[0].landlord_id;
      if (isPropertyUnavailable(
        propResult.rows[0].availability_status,
        propResult.rows[0].status,
      )) {
        await client.query('ROLLBACK');
        return res.status(409).json({ error: 'Property is not available for booking.' });
      }
      
      if (!landlordId) {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: 'Property has no landlord assigned.' });
      }

      // Calculate nights and server-side totalPrice
      const cIn = new Date(checkInDate);
      const cOut = new Date(checkOutDate);
      if (
        !Number.isFinite(cIn.getTime()) ||
        !Number.isFinite(cOut.getTime()) ||
        cOut <= cIn
      ) {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: 'Invalid booking date range.' });
      }
      const calculatedTotalPrice = BOOKING_VIEWING_FEE_KES;

      // Availability Engine: Check for overlapping confirmed bookings
      const overlapCheck = await client.query(
        `SELECT id FROM bookings 
         WHERE property_id = $1 
         AND status = 'confirmed'
         AND (check_in_date, check_out_date) OVERLAPS ($2::date, $3::date)`,
        [propertyId, checkInDate, checkOutDate]
      );

      if (overlapCheck.rows.length > 0) {
        await client.query('ROLLBACK');
        return res.status(409).json({ error: 'Property is already booked for these dates.' });
      }

      // Strict Idempotency Check
      const existingBooking = await client.query(
        `SELECT id FROM bookings 
         WHERE property_id = $1 AND tenant_id = $2 AND status IN ('pending', 'confirmed')`,
        [propertyId, req.auth!.id]
      );

      if (existingBooking.rows.length > 0) {
        await client.query('ROLLBACK');
        return res.status(409).json({ error: 'You already have an active booking or request for this property.' });
      }

      // Create booking
      const bookingResult = await client.query(
        `INSERT INTO bookings (property_id, tenant_id, landlord_id, check_in_date, check_out_date, status, total_price, notes)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         RETURNING id, property_id, tenant_id, landlord_id, check_in_date, check_out_date, status, total_price, notes, created_at`,
        [propertyId, req.auth!.id, landlordId, checkInDate, checkOutDate, 'pending', calculatedTotalPrice, notes || null],
      );

      bookingData = bookingResult.rows[0];
      await client.query('COMMIT');
      try {
        const tenantRes = await query('SELECT name FROM users WHERE id = $1 LIMIT 1', [req.auth!.id]);
        const pRes = await query('SELECT title FROM properties WHERE id = $1 LIMIT 1', [propertyId]);
        const tenantName = tenantRes.rows[0]?.name || 'A tenant';
        const pName = pRes.rows[0]?.title || 'your property';
        await queueUserPush(landlordId, 'New Booking Request', `${tenantName} requested to book ${pName}.`, { type: 'new_booking', bookingId: bookingData.id });
      } catch(e) { console.error('Push error:', e); }
    } catch (dbErr) {
      await client.query('ROLLBACK');
      throw dbErr;
    }

    res.status(201).json({ data: bookingData });
  } catch (error) {
    next(error);
  } finally {
    client?.release();
  }
});

// Get bookings for tenant
router.get('/tenant', requireAuth, authorize('tenant'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    await refundExpiredBookingEscrows();

    const result = await query(
      `SELECT b.id,
              b.property_id,
              b.check_in_date,
              b.check_out_date,
              b.status,
              b.total_price,
              b.notes,
              b.created_at,
              p.title,
              p.city,
              p.category,
              p.image_url,
              u.id AS landlord_id,
              u.name AS landlord_name,
              u.email AS landlord_email
       FROM bookings b
       JOIN properties p ON p.id = b.property_id
       LEFT JOIN users u ON u.id = b.landlord_id
       WHERE b.tenant_id = $1
       ORDER BY b.created_at DESC`,
      [req.auth!.id],
    );

    res.json({ data: result.rows });
  } catch (error) {
    next(error);
  }
});

// Get bookings for landlord
router.get('/landlord', requireAuth, authorize('landlord', 'host'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    await refundExpiredBookingEscrows();

    const result = await query(
      `SELECT b.id,
              b.property_id,
              b.landlord_id,
              b.tenant_id,
              b.check_in_date,
              b.check_out_date,
              b.status,
              b.total_price,
              b.notes,
              b.created_at,
              p.title,
              p.city,
              p.category,
              p.image_url,
              t.name AS tenant_name,
              t.email AS tenant_email,
              t.phone AS tenant_phone
       FROM bookings b
       JOIN properties p ON p.id = b.property_id
       LEFT JOIN users t ON t.id = b.tenant_id
       WHERE b.landlord_id = $1
       ORDER BY b.created_at DESC`,
      [req.auth!.id],
    );

    res.json({ data: result.rows });
  } catch (error) {
    next(error);
  }
});

// Confirm booking (landlord confirms)
router.patch('/:id/confirm', requireAuth, authorize('landlord', 'host'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const bookingId = req.params.id;

    // Verify the landlord owns this booking
    const checkResult = await query('SELECT landlord_id FROM bookings WHERE id = $1 LIMIT 1', [
      bookingId,
    ]);

    if (checkResult.rowCount === 0) {
      return res.status(404).json({ error: 'Booking not found.' });
    }

    if (checkResult.rows[0].landlord_id !== req.auth!.id) {
      return res.status(403).json({ error: 'Only the landlord can confirm this booking.' });
    }

    const result = await query(
      'UPDATE bookings SET status = $1, updated_at = now() WHERE id = $2 RETURNING *',
      ['confirmed', bookingId],
    );
    try {
      const b = result.rows[0];
      const pRes = await query('SELECT title FROM properties WHERE id = $1 LIMIT 1', [b.property_id]);
      const pName = pRes.rows[0]?.title || 'a property';
      await queueUserPush(b.tenant_id, '? Booking Approved', `Your booking for ${pName} was approved!`, { type: 'booking_approved', bookingId });
    } catch(e) { console.error('Push error:', e); }
    res.json({ data: result.rows[0] });
  } catch (error) {
    next(error);
  }
});

// Complete booking after the stay ends and release the held payment.
router.patch('/:id/complete', requireAuth, authorize('landlord', 'host'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const booking = await completeBookingWithEscrow(req.params.id, req.auth!.id);
    await settleReferralReward(req.params.id);
    return res.json({ data: booking });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Could not complete booking.';
    if (message.includes('not found')) return res.status(404).json({ error: message });
    if (message.includes('Only the landlord')) return res.status(403).json({ error: message });
    if (message.includes('Only confirmed') || message.includes('checkout date') || message.includes('escrow')) {
      return res.status(409).json({ error: message });
    }
    return next(error);
  }
});

// Reject booking (landlord rejects)
router.patch('/:id/reject', requireAuth, authorize('landlord', 'host'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const bookingId = req.params.id;
    const { reason } = req.body as { reason?: string };

    // Verify the landlord owns this booking
    const checkResult = await query('SELECT landlord_id FROM bookings WHERE id = $1 LIMIT 1', [
      bookingId,
    ]);

    if (checkResult.rowCount === 0) {
      return res.status(404).json({ error: 'Booking not found.' });
    }

    if (checkResult.rows[0].landlord_id !== req.auth!.id) {
      return res.status(403).json({ error: 'Only the landlord can reject this booking.' });
    }

    const notesUpdate = reason ? `Rejected by landlord: ${reason}` : 'Rejected by landlord';

    const result = await query(
      `UPDATE bookings 
       SET status = $1, 
           notes = CASE WHEN notes IS NULL OR notes = '' THEN $2 ELSE notes || ' | ' || $2 END, 
           updated_at = now() 
       WHERE id = $3 
       RETURNING *`,
      ['rejected', notesUpdate, bookingId],
    );
    await settleEscrow(bookingId, 'refund');
    try {
      const b = result.rows[0];
      const pRes = await query('SELECT title FROM properties WHERE id = $1 LIMIT 1', [b.property_id]);
      const pName = pRes.rows[0]?.title || 'a property';
      await queueUserPush(b.tenant_id, '? Booking Declined', `Your booking for ${pName} was declined.`, { type: 'booking_declined', bookingId });
    } catch(e) { console.error('Push error:', e); }
    res.json({ data: result.rows[0] });
  } catch (error) {
    next(error);
  }
});

// Cancel booking (landlord or tenant can cancel)
router.patch('/:id/cancel', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const bookingId = req.params.id;
    const { reason } = req.body as { reason?: string };

    // Verify the user is either landlord or tenant
    const checkResult = await query(
      'SELECT landlord_id, tenant_id FROM bookings WHERE id = $1 LIMIT 1',
      [bookingId],
    );

    if (checkResult.rowCount === 0) {
      return res.status(404).json({ error: 'Booking not found.' });
    }

    const booking = checkResult.rows[0];
    const isLandlord = booking.landlord_id === req.auth!.id;
    const isTenant = booking.tenant_id === req.auth!.id;

    if (isLandlord && !isTenant) {
      const access = await query(
        'SELECT role, roles, landlord_verified FROM users WHERE id = $1 LIMIT 1',
        [req.auth!.id],
      );
      const account = access.rows[0];
      const roles = Array.isArray(account?.roles)
        ? account.roles.map((role: string) => role.toLowerCase())
        : [account?.role?.toLowerCase() ?? ''];
      if (account?.landlord_verified !== true ||
          !roles.some((role: string) => role === 'landlord' || role === 'host')) {
        return res.status(403).json({ error: 'Approved landlord access is required.' });
      }
    }

    if (!isLandlord && !isTenant) {
      return res
        .status(403)
        .json({ error: 'Only landlord or tenant can cancel this booking.' });
    }

    const notesUpdate = reason ? `Cancelled by ${isLandlord ? 'landlord' : 'tenant'}: ${reason}` : null;

    const result = await query(
      `UPDATE bookings 
       SET status = $1, notes = CASE WHEN $2::text IS NOT NULL THEN COALESCE(notes, '') || ' ' || $2 ELSE notes END, updated_at = now() 
       WHERE id = $3 
       RETURNING *`,
      ['cancelled', notesUpdate, bookingId],
    );
    await settleEscrow(bookingId, 'refund');
    try {
      const b = result.rows[0];
      const notifyUserId = isTenant ? b.landlord_id : b.tenant_id;
      const actor = isTenant ? 'Tenant' : 'Landlord';
      const pRes = await query('SELECT title FROM properties WHERE id = $1 LIMIT 1', [b.property_id]);
      const pName = pRes.rows[0]?.title || 'a property';
      await queueUserPush(notifyUserId, 'Booking Cancelled', `${actor} cancelled the booking for ${pName}.`, { type: 'booking_cancelled', bookingId });
    } catch(e) { console.error('Push error:', e); }
    res.json({ data: result.rows[0] });
  } catch (error) {
    next(error);
  }
});

// Get booking by ID
router.get('/:id', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    await refundExpiredBookingEscrows();

    const bookingId = req.params.id;

    const result = await query(
      `SELECT b.id,
              b.property_id,
              b.landlord_id,
              b.tenant_id,
              b.check_in_date,
              b.check_out_date,
              b.status,
              b.total_price,
              b.notes,
              b.created_at,
              p.title,
              p.city,
              p.category,
              p.image_url,
              p.description,
              u.name AS landlord_name,
              u.email AS landlord_email,
              t.name AS tenant_name,
              t.email AS tenant_email
       FROM bookings b
       JOIN properties p ON p.id = b.property_id
       LEFT JOIN users u ON u.id = b.landlord_id
       LEFT JOIN users t ON t.id = b.tenant_id
       WHERE b.id = $1
       AND (b.landlord_id = $2 OR b.tenant_id = $2)
       LIMIT 1`,
      [bookingId, req.auth!.id],
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Booking not found or access denied.' });
    }

    const booking = result.rows[0];
    if (booking.landlord_id === req.auth!.id &&
        booking.tenant_id !== req.auth!.id) {
      const access = await query(
        'SELECT role, roles, landlord_verified FROM users WHERE id = $1 LIMIT 1',
        [req.auth!.id],
      );
      const account = access.rows[0];
      const roles = Array.isArray(account?.roles)
        ? account.roles.map((role: string) => role.toLowerCase())
        : [account?.role?.toLowerCase() ?? ''];
      if (account?.landlord_verified !== true ||
          !roles.some((role: string) => role === 'landlord' || role === 'host')) {
        return res.status(403).json({ error: 'Approved landlord access is required.' });
      }
    }

    res.json({ data: booking });
  } catch (error) {
    next(error);
  }
});

export default router;



