console.log("Backend Running");

const express = require('express');
const app = express();

// Ensure all necessary middleware and routes are set up
app.use(express.json());

// Example endpoint
app.get('/api/status', (req, res) => {
    res.json({ status: 'API is working' });
});
