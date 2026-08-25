import re

with open("backend/src/routes/admin.ts", "r", encoding="utf-8") as f:
    code = f.read()

overview_route = """
// GET /admin/overview - Dashboard stats
router.get('/overview', requireAuth, authorize('admin'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const usersRes = await query(`SELECT COUNT(*)::int as count FROM users`);
    const propsRes = await query(`SELECT COUNT(*)::int as count FROM properties`);
    const pendingKycRes = await query(`SELECT COUNT(*)::int as count FROM verifications WHERE status IN ('submitted', 'under_review')`);
    const revenueRes = await query(`SELECT COALESCE(SUM(total_price), 0)::numeric as total FROM bookings WHERE status IN ('confirmed', 'completed')`);
    const monthlyRevRes = await query(`SELECT COALESCE(SUM(total_price), 0)::numeric as total FROM bookings WHERE status IN ('confirmed', 'completed') AND created_at > now() - interval '30 days'`);

    res.json({
      success: true,
      data: {
        totalUsers: usersRes.rows[0].count,
        totalProperties: propsRes.rows[0].count,
        pendingVerifications: pendingKycRes.rows[0].count,
        totalRevenue: parseFloat(revenueRes.rows[0].total) || 0,
        monthlyRevenue: parseFloat(monthlyRevRes.rows[0].total) || 0,
        chartData: [],
        backlogData: [],
        verificationData: [],
        retentionData: [],
        cohortData: []
      }
    });
  } catch (err) {
    next(err);
  }
});
"""

if "router.get('/overview'" not in code:
    code = code.replace("export default router;", overview_route + "\nexport default router;")
    with open("backend/src/routes/admin.ts", "w", encoding="utf-8") as f:
        f.write(code)
    print("Added /overview endpoint")
else:
    print("Already exists")
