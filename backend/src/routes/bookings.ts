import { Router, Request, Response, NextFunction } from 'express';
import { query } from '../db.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();

// Create a new booking (tenant creates booking)
router.post('/', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { propertyId, checkInDate, checkOutDate, totalPrice, notes } = req.body as {
      propertyId?: string;
      checkInDate?: string;
      checkOutDate?: string;
      totalPrice?: number;
      notes?: string;
    };

    if (!propertyId || !checkInDate || !checkOutDate || !totalPrice) {
      return res.status(400).json({
        error: 'propertyId, checkInDate, checkOutDate, and totalPrice are required.',
      });
    }

    // Availability Engine: Check for overlapping confirmed bookings
    const overlapCheck = await query(
      `SELECT id FROM bookings 
       WHERE property_id = $1 
       AND status = 'confirmed'
       AND (check_in_date, check_out_date) OVERLAPS ($2::date, $3::date)`,
      [propertyId, checkInDate, checkOutDate]
    );

    if (overlapCheck.rowCount! > 0) {
      return res.status(409).json({ error: 'Property is already booked for these dates.' });
    }

    // Strict Idempotency Check: Prevent the same tenant from having multiple 
    // active (pending or confirmed) bookings for the same property.
    const existingBooking = await query(
      `SELECT id FROM bookings 
       WHERE property_id = $1 AND tenant_id = $2 AND status IN ('pending', 'confirmed')`,
      [propertyId, req.auth!.id]
    );

    if (existingBooking.rowCount! > 0) {
      return res.status(400).json({ error: 'You already have an active booking or request for this property.' });
    }

    // Get property and landlord info
    const propResult = await query(
      'SELECT id, landlord_id, price FROM properties WHERE id = $1 LIMIT 1',
      [propertyId],
    );

    if (propResult.rowCount === 0) {
      return res.status(404).json({ error: 'Property not found.' });
    }

    const landlordId = propResult.rows[0].landlord_id;
    if (!landlordId) {
      return res.status(400).json({ error: 'Property has no landlord assigned.' });
    }

    // Create booking
    const bookingResult = await query(
      `INSERT INTO bookings (property_id, tenant_id, landlord_id, check_in_date, check_out_date, status, total_price, notes)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING id, property_id, tenant_id, landlord_id, check_in_date, check_out_date, status, total_price, notes, created_at`,
      [propertyId, req.auth!.id, landlordId, checkInDate, checkOutDate, 'pending', totalPrice, notes || null],
    );

    res.status(201).json({ data: bookingResult.rows[0] });
  } catch (error) {
    next(error);
  }
});

// Get bookings for tenant
router.get('/tenant', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    // Auto-complete confirmed bookings that have passed their check-out date
    await query(
      `UPDATE bookings 
       SET status = 'completed', updated_at = now() 
       WHERE status = 'confirmed' AND check_out_date < CURRENT_DATE`,
      []
    );

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
router.get('/landlord', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    // Auto-complete confirmed bookings that have passed their check-out date
    await query(
      `UPDATE bookings 
       SET status = 'completed', updated_at = now() 
       WHERE status = 'confirmed' AND check_out_date < CURRENT_DATE`,
      []
    );

    const result = await query(
      `SELECT b.id,
              b.property_id,
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
router.patch('/:id/confirm', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
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

    res.json({ data: result.rows[0] });
  } catch (error) {
    next(error);
  }
});

// Reject booking (landlord rejects)
router.patch('/:id/reject', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
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

    res.json({ data: result.rows[0] });
  } catch (error) {
    next(error);
  }
});

// Get booking by ID
router.get('/:id', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    // Auto-complete this specific booking if check-out date has passed
    await query(
      `UPDATE bookings 
       SET status = 'completed', updated_at = now() 
       WHERE id = $1 AND status = 'confirmed' AND check_out_date < CURRENT_DATE`,
      [req.params.id]
    );

    const bookingId = req.params.id;

    const result = await query(
      `SELECT b.id,
              b.property_id,
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

    res.json({ data: result.rows[0] });
  } catch (error) {
    next(error);
  }
});

export default router;
