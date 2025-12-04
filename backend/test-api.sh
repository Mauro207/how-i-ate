#!/bin/bash
# Test script for How I Ate API
# This script demonstrates the API flow with example requests
# 
# Prerequisites:
# - Backend server must be running (npm start)
# - MongoDB must be connected
# - Superadmin must be initialized (npm run init-superadmin)

BASE_URL="http://localhost:3000"

echo "==================================="
echo "How I Ate API Test Script"
echo "==================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 1. Health Check
echo -e "${BLUE}1. Testing Health Check...${NC}"
curl -s "${BASE_URL}/api/health" | jq '.'
echo ""

# 2. Login as Superadmin
echo -e "${BLUE}2. Login as Superadmin...${NC}"
SUPERADMIN_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "superadmin@howiate.com",
    "password": "SuperAdmin123!"
  }')
SUPERADMIN_TOKEN=$(echo "$SUPERADMIN_RESPONSE" | jq -r '.token')
echo "$SUPERADMIN_RESPONSE" | jq '.'
echo ""

if [ "$SUPERADMIN_TOKEN" = "null" ]; then
  echo -e "${RED}Failed to login as superadmin. Make sure to run 'npm run init-superadmin' first.${NC}"
  exit 1
fi

# 3. Create Admin User
echo -e "${BLUE}3. Creating Admin User (as Superadmin)...${NC}"
curl -s -X POST "${BASE_URL}/api/auth/create-admin" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${SUPERADMIN_TOKEN}" \
  -d '{
    "username": "admin1",
    "email": "admin1@example.com",
    "password": "admin123"
  }' | jq '.'
echo ""

# 4. Login as Admin
echo -e "${BLUE}4. Login as Admin...${NC}"
ADMIN_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin1@example.com",
    "password": "admin123"
  }')
ADMIN_TOKEN=$(echo "$ADMIN_RESPONSE" | jq -r '.token')
echo "$ADMIN_RESPONSE" | jq '.'
echo ""

# 5. Register Regular User
echo -e "${BLUE}5. Registering Regular User...${NC}"
USER_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "testuser@example.com",
    "password": "user123"
  }')
USER_TOKEN=$(echo "$USER_RESPONSE" | jq -r '.token')
echo "$USER_RESPONSE" | jq '.'
echo ""

# 6. Create Restaurant (as Admin)
echo -e "${BLUE}6. Creating Restaurant (as Admin)...${NC}"
RESTAURANT_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/restaurants" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -d '{
    "name": "The Great Italian Restaurant",
    "description": "Authentic Italian cuisine with traditional recipes",
    "address": "123 Main St, New York, NY 10001",
    "cuisine": "Italian"
  }')
RESTAURANT_ID=$(echo "$RESTAURANT_RESPONSE" | jq -r '.restaurant._id')
echo "$RESTAURANT_RESPONSE" | jq '.'
echo ""

# 7. Get All Restaurants (as User)
echo -e "${BLUE}7. Getting All Restaurants (as User)...${NC}"
curl -s -X GET "${BASE_URL}/api/restaurants" \
  -H "Authorization: Bearer ${USER_TOKEN}" | jq '.'
echo ""

# 8. Create Review (as User)
echo -e "${BLUE}8. Creating Review (as User)...${NC}"
REVIEW_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/reviews/restaurant/${RESTAURANT_ID}" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${USER_TOKEN}" \
  -d '{
    "rating": 5,
    "comment": "Excellent food and service! The pasta was amazing!"
  }')
REVIEW_ID=$(echo "$REVIEW_RESPONSE" | jq -r '.review._id')
echo "$REVIEW_RESPONSE" | jq '.'
echo ""

# 9. Get All Reviews for Restaurant
echo -e "${BLUE}9. Getting All Reviews for Restaurant...${NC}"
curl -s -X GET "${BASE_URL}/api/reviews/restaurant/${RESTAURANT_ID}" \
  -H "Authorization: Bearer ${USER_TOKEN}" | jq '.'
echo ""

# 10. Update Review (as User - owner)
echo -e "${BLUE}10. Updating Review (as User/Owner)...${NC}"
curl -s -X PUT "${BASE_URL}/api/reviews/${REVIEW_ID}" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${USER_TOKEN}" \
  -d '{
    "rating": 4,
    "comment": "Good food, but service was a bit slow."
  }' | jq '.'
echo ""

# 11. Get Current User Info
echo -e "${BLUE}11. Getting Current User Info...${NC}"
curl -s -X GET "${BASE_URL}/api/auth/me" \
  -H "Authorization: Bearer ${USER_TOKEN}" | jq '.'
echo ""

echo -e "${GREEN}==================================="
echo "All tests completed successfully!"
echo "===================================${NC}"
echo ""
echo "Summary:"
echo "- Superadmin Token: ${SUPERADMIN_TOKEN:0:20}..."
echo "- Admin Token: ${ADMIN_TOKEN:0:20}..."
echo "- User Token: ${USER_TOKEN:0:20}..."
echo "- Restaurant ID: ${RESTAURANT_ID}"
echo "- Review ID: ${REVIEW_ID}"
