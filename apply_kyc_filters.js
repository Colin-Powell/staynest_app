const fs = require('fs');
const file = 'frontend/lib/screens/super_admin/super_admin_kyc.dart';
let text = fs.readFileSync(file, 'utf8');

text = text.replace(
  `Text('Review landlord documents and approve them to allow listing creation.', style: GoogleFonts.poppins(color: AppColors.gray500)),
                const SizedBox(height: 24),`,
  `Text('Review landlord documents and approve them to allow listing creation.', style: GoogleFonts.poppins(color: AppColors.gray500)),
                const SizedBox(height: 16),
                // Local Filters
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Filter by name or email...',
                          prefixIcon: const Icon(Icons.search, color: AppColors.gray500),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outlineLight)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onChanged: (value) {},
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outlineLight)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        value: 'All',
                        items: ['All', 'Pending', 'Approved', 'Rejected'].map((status) => DropdownMenuItem(value: status, child: Text(status))).toList(),
                        onChanged: (value) {},
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),`
);

fs.writeFileSync(file, text, 'utf8');
console.log('Added filters to KYC page');
