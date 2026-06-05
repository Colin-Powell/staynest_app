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

console.log('Testing backend endpoints...\n');

async function testEndpoint(path, method = 'GET') {
  try {
    const url = `http://localhost:8080${path}`;
    const options = {
      method,
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    };
    
    console.log(`${method} ${url}`);
    const response = await fetch(url, options);
    console.log(`  Status: ${response.status}`);
    
    const text = await response.text();
    if (text.length > 200) {
      console.log(`  Response: ${text.substring(0, 200)}...`);
    } else {
      console.log(`  Response: ${text}`);
    }
    console.log();
  } catch (error) {
    console.log(`  ERROR: ${error.message}\n`);
  }
}

await testEndpoint('/');
await testEndpoint('/properties');
await testEndpoint('/properties/me');
await testEndpoint('/users/me');
