const request = require('supertest');
const app = require('../backend/index.js');

describe('GET /api/status', () => {
    it('should return API status', async () => {
        const res = await request(app).get('/api/status');
        expect(res.statusCode).toEqual(200);
        expect(res.body).toHaveProperty('status', 'API is working');
    });
});
