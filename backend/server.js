const express = require('express');
const app = express();
const authRoutes = require('./routes/auth');

// ...other routes...

app.use('/api/auth', authRoutes);

// ...other middleware and server setup...

app.listen(3000, () => {
  console.log('Server is running on port 3000');
});
