import jwt from 'jsonwebtoken';
import fetch from 'node-fetch';

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

console.log('Testing property endpoints with image URLs...\n');

async function testEndpoint(path, method = 'GET') {
  try {
    const response = await fetch(`http://localhost:8080${path}`, {
      method,
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    });

    if (response.ok) {
      const data = await response.json();
      console.log(`✅ ${method} ${path} - Status: ${response.status}`);
      
      if (data.data && Array.isArray(data.data)) {
        console.log(`   Found ${data.data.length} properties:\n`);
        data.data.forEach((prop, i) => {
          console.log(`   ${i + 1}. ${prop.title}`);
          console.log(`      City: ${prop.city}, Price: KES ${prop.price}`);
          console.log(`      Image URL: ${prop.image_url}\n`);
        });
      }
    } else {
      console.log(`❌ ${method} ${path} - Status: ${response.status}`);
    }
  } catch (error) {
    console.log(`❌ ${method} ${path} - Error: ${error.message}`);
  }
}

await testEndpoint('/api/properties/me');
console.log('\n---\n');
await testEndpoint('/api/properties');
