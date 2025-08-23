#!/bin/bash

# Allixios Services Stop Script
# Stops all running microservices

set -e

echo "🛑 Stopping Allixios Microservices Platform"
echo "==========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to stop a service
stop_service() {
    local service_name=$1
    local service_path=$2
    
    if [ -d "$service_path" ]; then
        local pid_file="$service_path/logs/$service_name.pid"
        
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file")
            
            if ps -p $pid > /dev/null 2>&1; then
                print_status "Stopping $service_name (PID: $pid)..."
                kill $pid
                
                # Wait for process to stop
                local count=0
                while ps -p $pid > /dev/null 2>&1 && [ $count -lt 10 ]; do
                    sleep 1
                    count=$((count + 1))
                done
                
                if ps -p $pid > /dev/null 2>&1; then
                    print_warning "Force killing $service_name..."
                    kill -9 $pid
                fi
                
                rm -f "$pid_file"
                print_status "$service_name stopped ✓"
            else
                print_warning "$service_name was not running"
                rm -f "$pid_file"
            fi
        else
            print_warning "No PID file found for $service_name"
        fi
    fi
}

# Stop all services
print_status "Stopping all microservices..."

stop_service "content-service" "content-service"
stop_service "user-service" "user-service"
stop_service "analytics-service" "analytics-service"
stop_service "seo-service" "seo-service"
stop_service "translation-service" "translation-service"
stop_service "notification-service" "notification-service"
stop_service "monetization-service" "monetization-service"

# Kill any remaining Node.js processes on our ports
print_status "Cleaning up any remaining processes..."

for port in 3001 3002 3003 3004 3005 3006 3007; do
    local pid=$(lsof -ti:$port 2>/dev/null || true)
    if [ ! -z "$pid" ]; then
        print_status "Killing process on port $port (PID: $pid)..."
        kill $pid 2>/dev/null || true
    fi
done

echo ""
print_status "All services stopped successfully! 🎉"
echo ""
print_status "Infrastructure services (Docker) are still running."
print_warning "To stop infrastructure: docker-compose -f ../infrastructure/docker/docker-compose.yml down"