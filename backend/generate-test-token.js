import jwt from 'jsonwebtoken';

// Create a test JWT token for the landlord user
const user = {
  id: 'cee785b0-a0b8-4291-a06e-43638fdf6ef0',
  email: 'oderocollonce5@gmail.com',
  role: 'landlord',
  verified: true,
};

const token = jwt.sign(user, 'replace-with-strong-secret', { expiresIn: '6h' });

console.log('Test JWT Token:');
console.log(token);
console.log('\nUse this token in the Authorization header:');
console.log(`Authorization: Bearer ${token}`);
