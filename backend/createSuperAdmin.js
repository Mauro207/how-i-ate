const mongoose = require('mongoose');
const dotenv = require('dotenv');
const User = require('./models/User');

// Load environment variables
dotenv.config();

const createSuperAdmin = async () => {
  try {
    // Connect to MongoDB
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('MongoDB connected successfully');
    
    // Check if superadmin already exists
    const existingSuperAdmin = await User.findOne({ role: 'superadmin' });
    
    if (existingSuperAdmin) {
      console.log('Superadmin already exists:', existingSuperAdmin.username);
      process.exit(0);
    }
    
    // Get password from environment variable or use default for development
    const superAdminPassword = process.env.SUPERADMIN_PASSWORD || 'SuperAdmin123!';
    
    if (!process.env.SUPERADMIN_PASSWORD) {
      console.warn('\nWARNING: Using default superadmin password!');
      console.warn('Set SUPERADMIN_PASSWORD environment variable for custom password.\n');
    }
    
    // Create superadmin user
    const superAdmin = new User({
      username: 'superadmin',
      email: 'superadmin@howiate.com',
      password: superAdminPassword,
      role: 'superadmin'
    });
    
    await superAdmin.save();
    
    console.log('Superadmin created successfully!');
    console.log('Username:', superAdmin.username);
    console.log('Email:', superAdmin.email);
    if (!process.env.SUPERADMIN_PASSWORD) {
      console.log('Password: SuperAdmin123! (default)');
    }
    console.log('\nIMPORTANT: Please change the password after first login!');
    
    process.exit(0);
  } catch (error) {
    console.error('Error creating superadmin:', error);
    process.exit(1);
  }
};

createSuperAdmin();
