#!/bin/bash

# Database setup script for n8n Agentic RAG System
# This script sets up the Supabase database with required tables and functions

set -e

echo "🚀 Setting up database for n8n Agentic RAG System..."

# Check if required environment variables are set
if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_SERVICE_ROLE_KEY" ]; then
    echo "❌ Error: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set"
    echo "Please create a .env file with your Supabase credentials"
    exit 1
fi

# Extract project ID from Supabase URL
PROJECT_ID=$(echo $SUPABASE_URL | sed 's/.*\/\/\([^.]*\)\.supabase\.co.*/\1/')
echo "📊 Setting up database for project: $PROJECT_ID"

# Set up vector store
echo "🔧 Setting up vector store..."
psql "$SUPABASE_URL" -f supabase_vector_store_setup.sql

# Set up inventory table
echo "🔧 Setting up inventory table..."
psql "$SUPABASE_URL" -f create_inventory_table.sql

# Import sample data
echo "📥 Importing sample data..."
psql "$SUPABASE_URL" -c "\copy inventory FROM 'Automotive_Inventory__Sample_.csv' WITH CSV HEADER;"

echo "✅ Database setup complete!"
echo ""
echo "Next steps:"
echo "1. Configure your n8n instance with the environment variables"
echo "2. Import the n8n workflow"
echo "3. Test the system with sample queries"
echo ""
echo "Your Supabase URL: $SUPABASE_URL"
echo "Vector store table: car_sales_knowledge_base"
echo "Inventory table: inventory"
