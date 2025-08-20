#!/bin/bash

# Allixios Custom n8n Nodes Installation Script

echo "🚀 Installing Allixios Custom n8n Nodes..."

# Check if n8n is installed
if ! command -v n8n &> /dev/null; then
    echo "❌ n8n is not installed. Please install n8n first:"
    echo "   npm install -g n8n"
    exit 1
fi

# Install dependencies
echo "📦 Installing dependencies..."
npm install

# Build TypeScript files
echo "🔨 Building TypeScript files..."
npm run build

# Create n8n custom nodes directory if it doesn't exist
N8N_CUSTOM_DIR="$HOME/.n8n/custom"
mkdir -p "$N8N_CUSTOM_DIR"

# Copy built files to n8n custom directory
echo "📁 Copying files to n8n custom directory..."
cp dist/*.js "$N8N_CUSTOM_DIR/"

# Copy package.json for n8n to recognize the nodes
cp package.json "$N8N_CUSTOM_DIR/"

echo "✅ Installation complete!"
echo ""
echo "📋 Next steps:"
echo "1. Restart your n8n instance"
echo "2. The Allixios nodes will appear in the 'Allixios' category"
echo "3. Configure your Supabase credentials in the nodes"
echo ""
echo "🔧 Available nodes:"
echo "   - Allixios Content Generator"
echo "   - Allixios SEO Analyzer" 
echo "   - Allixios Analytics Processor"
echo "   - Allixios Workflow Monitor"