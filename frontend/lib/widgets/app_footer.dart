import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  static const _text = Color(0xFF202124);
  static const _muted = Color(0xFF70757A);
  static const _border = Color(0xFFE5E7EB);

  Future<void> _openExternal(String path) async {
    final url = Uri.parse('https://staynest.top$path');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _openRoute(BuildContext context, String route) {
    Navigator.of(context).pushNamed(route);
  }

  Widget _link(BuildContext context, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: _muted,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildLinkColumn(String title, List<Widget> links) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _text,
            ),
          ),
        ),
        ...links,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double width = constraints.maxWidth;
              final bool isDesktop = width >= 900;
              final bool isTablet = width >= 600 && width < 900;
              final bool isMobile = width < 600;

              // 1. Company Info & Logo Widget
              final Widget companyInfo = SizedBox(
                width: isDesktop ? 280 : double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: 40,
                      width: 160,
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'The modern platform for renting, discovering, and managing properties with ease and total security.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        height: 1.7,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              );

              // 2. Link Columns Data
              final List<Widget> linkColumns = [
                _buildLinkColumn('Product', [
                  _link(context, 'Features', () => _openExternal('/features')),
                  _link(context, 'Pricing', () => _openExternal('/pricing')),
                  _link(context, 'Blog', () => _openExternal('/blog')),
                ]),
                _buildLinkColumn('Company', [
                  _link(context, 'About', () => _openRoute(context, '/about')),
                  _link(context, 'Careers', () => _openExternal('/contact')),
                  _link(context, 'Support', () => _openRoute(context, '/help_support')),
                ]),
                _buildLinkColumn('Developers', [
                  _link(context, 'API', () => _openExternal('/#join-waitlist')),
                  _link(context, 'Documentation', () => _openExternal('/#join-waitlist')),
                ]),
                _buildLinkColumn('Legal', [
                  _link(context, 'Privacy', () => _openRoute(context, '/privacy')),
                  _link(context, 'Terms', () => _openExternal('/terms')),
                ]),
              ];

              // 3. Bottom Row Data (Copyright & Socials)
              final Widget copyright = Text(
                '© ${DateTime.now().year} StayNest. All rights reserved.',
                style: GoogleFonts.poppins(fontSize: 12, color: _muted),
              );

              final Widget socials = Wrap(
                spacing: 20,
                runSpacing: 12,
                children: [
                  ('Twitter', 'https://twitter.com/StayNestApp'),
                  ('LinkedIn', 'https://www.linkedin.com/company/staynest'),
                  ('Instagram', 'https://www.instagram.com/StayNestApp'),
                ].map((social) {
                  return InkWell(
                    onTap: () => launchUrl(
                      Uri.parse(social.$2),
                      mode: LaunchMode.externalApplication,
                    ),
                    hoverColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    child: Text(
                      social.$1,
                      style: GoogleFonts.poppins(fontSize: 12, color: _muted),
                    ),
                  );
                }).toList(),
              );

              // 4. Construct Layout
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- TOP SECTION (Links & Info) ---
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        companyInfo,
                        const SizedBox(width: 64),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: linkColumns.map((col) => Expanded(child: col)).toList(),
                          ),
                        ),
                      ],
                    )
                  else if (isTablet)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        companyInfo,
                        const SizedBox(height: 40),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: linkColumns.map((col) => Expanded(child: col)).toList(),
                        ),
                      ],
                    )
                  else // isMobile
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        companyInfo,
                        const SizedBox(height: 32),
                        // Split into a 2x2 grid for Mobile
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  linkColumns[0], // Product
                                  const SizedBox(height: 32),
                                  linkColumns[2], // Developers
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  linkColumns[1], // Company
                                  const SizedBox(height: 32),
                                  linkColumns[3], // Legal
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                  const SizedBox(height: 48),
                  const Divider(height: 1, color: _border),
                  const SizedBox(height: 24),

                  // --- BOTTOM SECTION (Copyright & Socials) ---
                  if (isMobile)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        copyright,
                        const SizedBox(height: 16),
                        socials,
                      ],
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        copyright,
                        socials,
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}