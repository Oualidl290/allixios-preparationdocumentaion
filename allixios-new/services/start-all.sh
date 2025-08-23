#!/bin/bash

# Allixios Services Startup Script
# Starts all microservices in development mode

set -e

echo "🚀 Starting Allixios Microservices Platform"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_service() {
    echo -e "${BLUE}[SERVICE]${NC} $1"
}

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    print_error "Node.js is not installed. Please install Node.js 18+ first."
    exit 1
fi

# Check Node.js version
NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    print_error "Node.js version 18+ is required. Current version: $(node -v)"
    exit 1
fi

print_status "Node.js version: $(node -v) ✓"

# Check if Docker is running (for infrastructure)
if ! docker info &> /dev/null; then
    print_warning "Docker is not running. Please start Docker for infrastructure services."
    print_warning "You can start infrastructure with: docker-compose -f ../infrastructure/docker/docker-compose.yml up -d"
fi

# Function to install dependencies for a service
install_dependencies() {
    local service_name=$1
    local service_path=$2
    
    if [ -d "$service_path" ]; then
        print_service "Installing dependencies for $service_name..."
        cd "$service_path"
        
        if [ -f "package.json" ]; then
            npm install --silent
            print_status "$service_name dependencies installed ✓"
        else
            print_warning "No package.json found for $service_name"
        fi
        
        cd - > /dev/null
    else
        print_warning "Service directory not found: $service_path"
    fi
}

# Function to start a service in background
start_service() {
    local service_name=$1
    local service_path=$2
    local port=$3
    
    if [ -d "$service_path" ]; then
        print_service "Starting $service_name on port $port..."
        cd "$service_path"
        
        # Create logs directory if it doesn't exist
        mkdir -p logs
        
        # Start service in background
        npm run dev > "logs/$service_name.log" 2>&1 &
        local pid=$!
        
        # Store PID for cleanup
        echo $pid > "logs/$service_name.pid"
        
        print_status "$service_name started (PID: $pid) ✓"
        cd - > /dev/null
        
        # Wait a moment for service to start
        sleep 2
    else
        print_warning "Service directory not found: $service_path"
    fi
}

# Install dependencies for all services
print_status "Installing dependencies for all services..."

install_dependencies "Shared Libraries" "shared"
install_dependencies "Content Service" "content-service"
install_dependencies "User Service" "user-service"
install_dependencies "Analytics Service" "analytics-service"
install_dependencies "SEO Service" "seo-service"
install_dependencies "Translation Service" "translation-service"
install_dependencies "Notification Service" "notification-service"
install_dependencies "Monetization Service" "monetization-service"

echo ""
print_status "All dependencies installed successfully!"
echo ""

# Start infrastructure check
print_status "Checking infrastructure services..."

# Check if PostgreSQL is accessible
if nc -z localhost 5432 2>/dev/null; then
    print_status "PostgreSQL is running ✓"
else
    print_warning "PostgreSQL is not accessible on localhost:5432"
    print_warning "Please start with: docker-compose -f ../infrastructure/docker/docker-compose.yml up -d postgres"
fi

# Check if MongoDB is accessible
if nc -z localhost 27017 2>/dev/null; then
    print_status "MongoDB is running ✓"
else
    print_warning "MongoDB is not accessible on localhost:27017"
    print_warning "Please start with: docker-compose -f ../infrastructure/docker/docker-compose.yml up -d mongodb"
fi

# Check if Redis is accessible
if nc -z localhost 6379 2>/dev/null; then
    print_status "Redis is running ✓"
else
    print_warning "Redis is not accessible on localhost:6379"
    print_warning "Please start with: docker-compose -f ../infrastructure/docker/docker-compose.yml up -d redis"
fi

echo ""

# Start all services
print_status "Starting all microservices..."
echo ""

start_service "content-service" "content-service" "3001"
start_service "user-service" "user-service" "3002"
start_service "analytics-service" "analytics-service" "3003"
start_service "seo-service" "seo-service" "3004"
start_service "translation-service" "translation-service" "3005"
start_service "notification-service" "notification-service" "3006"
start_service "monetization-service" "monetization-service" "3007"

echo ""
print_status "All services started successfully!"
echo ""

# Display service URLs
echo "🌐 Service URLs:"
echo "=================="
echo "Content Service:      http://localhost:3001"
echo "User Service:         http://localhost:3002"
echo "Analytics Service:    http://localhost:3003"
echo "SEO Service:          http://localhost:3004"
echo "Translation Service:  http://localhost:3005"
echo "Notification Service: http://localhost:3006"
echo "Monetization Service: http://localhost:3007"
echo ""

echo "📚 API Documentation:"
echo "======================"
echo "Content Service:      http://localhost:3001/api-docs"
echo "User Service:         http://localhost:3002/api-docs"
echo "Analytics Service:    http://localhost:3003/api-docs"
echo "SEO Service:          http://localhost:3004/api-docs"
echo "Translation Service:  http://localhost:3005/api-docs"
echo "Notification Service: http://localhost:3006/api-docs"
echo "Monetization Service: http://localhost:3007/api-docs"
echo ""

echo "❤️  Health Checks:"
echo "=================="
echo "Content Service:      http://localhost:3001/health"
echo "User Service:         http://localhost:3002/health"
echo "Analytics Service:    http://localhost:3003/health"
echo "SEO Service:          http://localhost:3004/health"
echo "Translation Service:  http://localhost:3005/health"
echo "Notification Service: http://localhost:3006/health"
echo "Monetization Service: http://localhost:3007/health"
echo ""

print_status "Platform is ready! 🎉"
echo ""
print_warning "To stop all services, run: ./stop-all.sh"
print_warning "To view logs, check the logs/ directory in each service"
echo ""

# Wait for user input to keep script running
echo "Press Ctrl+C to stop all services..."
trap 'echo ""; print_status "Stopping all services..."; ./stop-all.sh; exit 0' INT

# Keep script running
while true; do
    sleep 1
done