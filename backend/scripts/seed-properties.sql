-- Seed script: Insert landlords and their properties
-- Run this after init-db.sql to populate with sample data

-- Insert sample landlords/agents
INSERT INTO users (id, name, email, phone, password_hash, role, avatar, verified) VALUES
  ('550e8400-e29b-41d4-a716-446655440001', 'John Kamau', 'john.kamau@property.com', '+254722123456', '$2a$12$dummyhash1', 'landlord', 'https://i.pravatar.cc/150?img=11', true),
  ('550e8400-e29b-41d4-a716-446655440002', 'Mary Wanjiku', 'mary.wanjiku@property.com', '+254722123457', '$2a$12$dummyhash2', 'landlord', 'https://i.pravatar.cc/150?img=32', true),
  ('550e8400-e29b-41d4-a716-446655440003', 'David Ochieng', 'david.ochieng@property.com', '+254722123458', '$2a$12$dummyhash3', 'landlord', 'https://i.pravatar.cc/150?img=68', true),
  ('550e8400-e29b-41d4-a716-446655440004', 'Leah Odhiambo', 'leah.odhiambo@property.com', '+254722123459', '$2a$12$dummyhash4', 'landlord', 'https://i.pravatar.cc/150?img=44', true),
  ('550e8400-e29b-41d4-a716-446655440005', 'Brian Otieno', 'brian.otieno@property.com', '+254722123460', '$2a$12$dummyhash5', 'landlord', 'https://i.pravatar.cc/150?img=28', true),
  ('550e8400-e29b-41d4-a716-446655440006', 'Aisha Njeri', 'aisha.njeri@property.com', '+254722123461', '$2a$12$dummyhash6', 'landlord', 'https://i.pravatar.cc/150?img=20', true)
ON CONFLICT (email) DO NOTHING;

-- Insert sample properties linked to landlords
INSERT INTO properties (id, title, description, category, city, price, bedrooms, bathrooms, area, image_url, lat, lng, landlord_id) VALUES
  ('prop-001', '11 Green Bank', 'Modern luxury home with great access to amenities and transport. Clean finishes and a comfortable layout.', 'Apartment', 'Kilifi', 14500, 2, 2, 120, 'assets/images/hero.jpg', 3.6410, 39.8560, '550e8400-e29b-41d4-a716-446655440001'),
  ('prop-002', 'Azure Heights', 'Stylish apartment with spacious rooms and a calm neighborhood vibe. Perfect for long stays.', 'Apartment', 'Mombasa', 12000, 3, 2, 150, 'assets/images/hero1.jpg', -4.0435, 39.6682, '550e8400-e29b-41d4-a716-446655440002'),
  ('prop-003', 'Modern Studio', 'A compact studio with everything you need—bright spaces, modern touches, and a clean environment.', 'Studio', 'Nairobi', 8000, 1, 1, 50, 'assets/images/hero3.jpg', -1.2864, 36.8172, '550e8400-e29b-41d4-a716-446655440003'),
  ('prop-004', 'Minimal Space', 'A simple and affordable space designed for comfort and convenience.', 'Studio', 'Nakuru', 5000, 1, 1, 40, 'assets/images/apertment1.jpg', -0.3031, 36.0800, '550e8400-e29b-41d4-a716-446655440004'),
  ('prop-005', 'Cozy Studio', 'Cozy interiors with a clean layout—ideal for individuals and couples.', 'Studio', 'Nairobi', 8000, 1, 1, 55, 'assets/images/apertment2.jpg', -1.2921, 36.8219, '550e8400-e29b-41d4-a716-446655440005'),
  ('prop-006', 'Luxury Bedsitter', 'Premium bedsitter with modern finishes and excellent security.', 'Apartment', 'Westlands, Nairobi', 15000, 2, 1, 80, 'assets/images/apertment3.jpg', -1.2669, 36.8010, '550e8400-e29b-41d4-a716-446655440006')
ON CONFLICT (id) DO NOTHING;
