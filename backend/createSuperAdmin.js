const mongoose = require('mongoose');
const dotenv = require('dotenv');
const User = require('./models/User');

// Load environment variables
dotenv.config();

const createSuperAdmin = async () => {
  try {
    // Connect to MongoDB
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('Connessione con MongoDB avvenuta con successo');
    
    // Check if superadmin already exists
    const existingSuperAdmin = await User.findOne({ role: 'superadmin' });
    
    if (existingSuperAdmin) {
      console.log('Superadmin esiste già:', existingSuperAdmin.username);
      process.exit(0);
    }
    
    // Create superadmin user with specified credentials
    // NOTE: These credentials are specified by project requirements
    // In production, consider using environment variables or secure configuration
    const superAdmin = new User({
      username: 'maurofontanarosa',
      email: 'maurofontanarosa@gmail.com',
      password: 'HowIAte2025@!',
      role: 'superadmin'
    });
    
    await superAdmin.save();
    
    console.log('Superadmin created successfully!');
    console.log('Username:', superAdmin.username);
    console.log('Email:', superAdmin.email);
    console.log('\nIMPORTANT: Please change the password after first login!');
    
    process.exit(0);
  } catch (error) {
    console.error('Errore nella creazione di superadmin:', error);
    process.exit(1);
  }
};

createSuperAdmin();
