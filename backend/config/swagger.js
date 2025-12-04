const swaggerJsdoc = require('swagger-jsdoc');

const options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'How I Ate API',
      version: '1.0.0',
      description: 'API documentation for How I Ate restaurant review application',
      contact: {
        name: 'API Support'
      }
    },
    servers: [
      {
        url: 'http://localhost:3000',
        description: 'Development server'
      }
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
          description: 'Enter JWT token obtained from login/register endpoint'
        }
      },
      schemas: {
        User: {
          type: 'object',
          properties: {
            id: {
              type: 'string',
              description: 'User ID'
            },
            username: {
              type: 'string',
              description: 'Username'
            },
            displayName: {
              type: 'string',
              description: 'Display name',
              nullable: true
            },
            email: {
              type: 'string',
              description: 'Email address'
            },
            role: {
              type: 'string',
              enum: ['user', 'admin', 'superadmin'],
              description: 'User role'
            },
            createdAt: {
              type: 'string',
              format: 'date-time',
              description: 'Account creation timestamp'
            }
          }
        },
        Restaurant: {
          type: 'object',
          properties: {
            _id: {
              type: 'string',
              description: 'Restaurant ID'
            },
            name: {
              type: 'string',
              description: 'Restaurant name'
            },
            description: {
              type: 'string',
              description: 'Restaurant description'
            },
            address: {
              type: 'string',
              description: 'Restaurant address'
            },
            cuisine: {
              type: 'string',
              description: 'Cuisine type'
            },
            createdBy: {
              type: 'string',
              description: 'User ID of creator'
            },
            createdAt: {
              type: 'string',
              format: 'date-time'
            }
          }
        },
        Review: {
          type: 'object',
          properties: {
            _id: {
              type: 'string',
              description: 'Review ID'
            },
            restaurant: {
              type: 'string',
              description: 'Restaurant ID'
            },
            user: {
              type: 'string',
              description: 'User ID'
            },
            rating: {
              type: 'integer',
              minimum: 1,
              maximum: 5,
              description: 'Rating (1-5)'
            },
            comment: {
              type: 'string',
              description: 'Review comment'
            },
            createdAt: {
              type: 'string',
              format: 'date-time'
            }
          }
        },
        Error: {
          type: 'object',
          properties: {
            message: {
              type: 'string',
              description: 'Error message'
            },
            error: {
              type: 'string',
              description: 'Detailed error (development only)'
            }
          }
        }
      }
    },
    security: [
      {
        bearerAuth: []
      }
    ]
  },
  apis: ['./routes/*.js']
};

const swaggerSpec = swaggerJsdoc(options);

module.exports = swaggerSpec;
