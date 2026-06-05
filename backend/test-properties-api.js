import jwt from 'jsonwebtoken';
import fetch from 'node-fetch';

// Create a JWT token for the user (simulating login)
const secret = 'replace-with-strong-secret';
const token = jwt.sign(
  {
    id: 'cee785b0-a0b8-4291-a06e-43638fdf6ef0',
    email: 'oderocollonce5@gmail.com',
    role: 'landlord',
    verified: true,
  },
  secret,
  { expiresIn: '6h' }
);

console.log('Testing GET /properties/me endpoint...\n');
console.log(`Token: ${token.substring(0, 30)}...\n`);

try {
  const response = await fetch('http://localhost:8080/properties/me', {
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
  });

  console.log(`Status: ${response.status}`);
  
  const data = await response.json();
  
  if (response.ok) {
    console.log(`\nSuccessfully fetched properties:`);
    console.log(`Found ${data.data.length} properties:\n`);
    data.data.forEach(prop => {
      console.log(`  ✓ ${prop.title}`);
      console.log(`    City: ${prop.city}, Price: KES ${prop.price}/month`);
      console.log(`    ID: ${prop.id}\n`);
    });
  } else {
    console.log('Error:', data);
  }
} catch (error) {
  console.error('Request failed:', error.message);
  console.log('\nMake sure the backend is running with: npm run dev');
}
