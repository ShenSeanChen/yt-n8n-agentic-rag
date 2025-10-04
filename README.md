# n8n AI Agentic RAG System for Automotive Sales

A comprehensive AI-powered RAG (Retrieval Augmented Generation) system built with n8n, Supabase, and OpenAI that enables intelligent automotive sales assistance through both vector search and structured data querying.

## 🚀 Features

- **AI Agentic RAG System**: Intelligent conversational AI that can answer questions about automotive inventory
- **Dual Data Sources**: 
  - Vector Store for semantic search of knowledge base documents
  - SQL Database for structured inventory queries
- **Google Drive Integration**: Automatic document ingestion and processing
- **OpenAI Integration**: Advanced embeddings and chat capabilities
- **Memory System**: Conversational context retention
- **Tool-based Architecture**: Extensible system for adding new capabilities

## 🏗️ Architecture

```mermaid
graph TB
    A[Google Drive Trigger] --> B[Download File]
    B --> C[Supabase Vector Store]
    C --> D[Default Data Loader]
    D --> E[Recursive Character Text Splitter]
    E --> F[OpenAI Embeddings]
    F --> C
    
    G[Chat Message] --> H[AI Agentic RAG]
    H --> I[OpenAI Chat Model]
    H --> J[Simple Memory]
    H --> K[HTTP Request Tool]
    K --> L[Supabase SQL Database]
    H --> M[Supabase Vector Store]
    
    style H fill:#e1f5fe
    style C fill:#f3e5f5
    style L fill:#e8f5e8
```

## 📋 Prerequisites

- [n8n](https://n8n.io/) (self-hosted or cloud)
- [Supabase](https://supabase.com/) account
- [OpenAI](https://openai.com/) API key
- [Google Drive API](https://developers.google.com/drive) credentials (optional)

## 🛠️ Setup Instructions

### 1. Database Setup

#### Supabase Vector Store Setup

1. Create a new Supabase project
2. Run the SQL script in `supabase_vector_store_setup.sql`:

```sql
-- Enable vector extension
create extension if not exists vector;

-- Create vector store table
create table if not exists public.car_sales_knowledge_base (
  id          bigserial primary key,
  content     text            not null,
  embedding   vector(1536)    not null,
  metadata    jsonb           not null default '{}'::jsonb,
  created_at  timestamptz     not null default now()
);

-- Create required RPC function for n8n
create or replace function public.match_documents(
  filter jsonb,
  match_count int,
  query_embedding vector
)
returns table(
  id bigint,
  content text,
  metadata jsonb,
  similarity float
)
language sql
stable
as $$
  select
    d.id,
    d.content,
    d.metadata,
    1 - (d.embedding <=> query_embedding) as similarity
  from public.car_sales_knowledge_base d
  where (filter is null or filter = '{}'::jsonb or d.metadata @> filter)
  order by d.embedding <=> query_embedding
  limit match_count
$$;
```

#### Supabase SQL Database Setup

1. Run the SQL script in `create_inventory_table.sql`:

```sql
-- Create inventory table
create table if not exists inventory (
  id bigserial primary key,
  make text,
  model text,
  trim text,
  year int,
  powertrain text,
  body_style text,
  color text,
  msrp_usd int,
  stock_qty int,
  vin text unique,
  location text,
  status text,
  lead_time_weeks int,
  test_drive_available boolean,
  demo_unit boolean,
  source_url text,
  created_at timestamptz default now()
);

-- Create search function
create or replace function public.search_inventory(
  p_color       text default null,
  p_make        text default null,
  p_model       text default null,
  p_powertrain  text default null,
  p_body_style  text default null,
  p_location    text default null,
  p_status      text default null,
  p_in_stock    boolean default null,
  p_price_min   int default null,
  p_price_max   int default null,
  p_limit       int default 25
)
returns table (
  make text,
  model text,
  car_trim text,
  year int,
  powertrain text,
  body_style text,
  color text,
  msrp_usd int,
  stock_qty int,
  vin text,
  location text,
  status text,
  lead_time_weeks int,
  test_drive_available boolean,
  demo_unit boolean,
  source_url text
)
language sql stable as $$
  select
    i.make, i.model, i.trim as car_trim, i.year, i.powertrain, i.body_style,
    i.color, i.msrp_usd, i.stock_qty, i.vin, i.location, i.status,
    i.lead_time_weeks, i.test_drive_available, i.demo_unit, i.source_url
  from public.inventory i
  where (p_color       is null or lower(i.color) = lower(trim(p_color)))
    and (p_make        is null or lower(i.make) = lower(trim(p_make)))
    and (p_model       is null or lower(i.model) = lower(trim(p_model)))
    and (p_powertrain  is null or lower(i.powertrain) = lower(trim(p_powertrain)))
    and (p_body_style  is null or lower(i.body_style) = lower(trim(p_body_style)))
    and (p_location    is null or lower(i.location) = lower(trim(p_location)))
    and (p_status      is null or lower(i.status) = lower(trim(p_status)))
    and (p_in_stock    is null or (case when p_in_stock then i.stock_qty > 0 else i.stock_qty = 0 end))
    and (p_price_min   is null or i.msrp_usd >= p_price_min)
    and (p_price_max   is null or i.msrp_usd <= p_price_max)
  order by i.msrp_usd asc, i.stock_qty desc
  limit p_limit;
$$;
```

2. Import sample data from `Automotive_Inventory__Sample_.csv`

### 2. Environment Configuration

Create a `.env` file with the following variables:

```env
# Supabase Configuration
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key

# OpenAI Configuration
OPENAI_API_KEY=your_openai_api_key

# Google Drive Configuration (Optional)
GOOGLE_DRIVE_CLIENT_ID=your_google_drive_client_id
GOOGLE_DRIVE_CLIENT_SECRET=your_google_drive_client_secret
GOOGLE_DRIVE_REFRESH_TOKEN=your_google_drive_refresh_token

# n8n Configuration
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=your_password
```

### 3. n8n Workflow Setup

1. Import the workflow from `n8n-workflow.json`
2. Configure the following nodes:

#### Supabase Vector Store Nodes
- **Vector Store 1**: Configure with your Supabase credentials
- **Vector Store 2**: Configure with your Supabase credentials

#### OpenAI Nodes
- **Embeddings OpenAI**: Set your OpenAI API key
- **Embeddings OpenAI1**: Set your OpenAI API key
- **OpenAI Chat Model**: Configure with your preferred model (e.g., gpt-4)

#### HTTP Request Node
- **Tool Configuration**: Set up the HTTP request to call your Supabase `search_inventory` function
- **URL**: `https://your-project.supabase.co/rest/v1/rpc/search_inventory`
- **Headers**: 
  - `apikey`: Your Supabase anon key
  - `Authorization`: `Bearer your_supabase_anon_key`
  - `Content-Type`: `application/json`

#### Google Drive Trigger (Optional)
- Configure with your Google Drive API credentials
- Set up webhook or polling trigger

### 4. Testing the System

1. Start your n8n instance
2. Activate the workflow
3. Send a test message to the chat interface
4. Verify that the AI agent can:
   - Search the vector store for relevant information
   - Query the inventory database
   - Provide comprehensive responses

## 🔧 Configuration Details

### Vector Store Configuration

The vector store uses OpenAI's `text-embedding-ada-002` model with 1536 dimensions. If you need to change the embedding model, update the vector dimension in the SQL schema.

### Inventory Search Parameters

The `search_inventory` function supports the following parameters:

- `p_color`: Filter by vehicle color
- `p_make`: Filter by manufacturer
- `p_model`: Filter by model
- `p_powertrain`: Filter by powertrain type (EV, ICE, HEV, PHEV)
- `p_body_style`: Filter by body style (Sedan, SUV, Hatchback, etc.)
- `p_location`: Filter by location
- `p_status`: Filter by status (In Stock, In Transit, Factory Order)
- `p_in_stock`: Filter by stock availability
- `p_price_min`: Minimum price filter
- `p_price_max`: Maximum price filter
- `p_limit`: Maximum number of results (default: 25)

## 📊 Sample Data

The repository includes sample automotive inventory data with the following structure:

- **Make**: Manufacturer (BYD, Tesla, Toyota, BMW, Ford, Nissan, Hyundai, Kia)
- **Model**: Vehicle model
- **Trim**: Trim level
- **Year**: Model year
- **Powertrain**: Engine type (EV, ICE, HEV, PHEV)
- **Body Style**: Vehicle category
- **Color**: Exterior color
- **MSRP**: Manufacturer's suggested retail price
- **Stock Quantity**: Available units
- **VIN**: Vehicle identification number
- **Location**: Dealership location
- **Status**: Availability status
- **Lead Time**: Delivery time in weeks
- **Test Drive**: Test drive availability
- **Demo Unit**: Whether it's a demo vehicle

## 🚀 Deployment Options

### Docker Compose (Recommended)

```yaml
version: '3.8'
services:
  n8n:
    image: n8nio/n8n
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=your_password
      - SUPABASE_URL=your_supabase_url
      - SUPABASE_ANON_KEY=your_supabase_anon_key
      - OPENAI_API_KEY=your_openai_api_key
    volumes:
      - n8n_data:/home/node/.n8n
    restart: unless-stopped

volumes:
  n8n_data:
```

### Manual Installation

1. Install n8n globally: `npm install n8n -g`
2. Start n8n: `n8n start`
3. Access the web interface at `http://localhost:5678`

## 🔍 Troubleshooting

### Common Issues

1. **Vector Store Connection Error**
   - Verify Supabase URL and API key
   - Ensure the `match_documents` function is created
   - Check that the vector extension is enabled

2. **OpenAI API Errors**
   - Verify API key is valid and has sufficient credits
   - Check rate limits and usage quotas

3. **Inventory Search Not Working**
   - Verify the `search_inventory` function is created
   - Check Supabase RLS policies
   - Ensure proper authentication headers

4. **Google Drive Integration Issues**
   - Verify OAuth credentials
   - Check webhook configuration
   - Ensure proper file permissions

### Debug Mode

Enable debug mode in n8n by setting:
```env
N8N_LOG_LEVEL=debug
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [n8n](https://n8n.io/) for the workflow automation platform
- [Supabase](https://supabase.com/) for the database and vector store
- [OpenAI](https://openai.com/) for the AI capabilities
- [Google Drive API](https://developers.google.com/drive) for file integration

## 📞 Support

For support and questions:
- Create an issue in this repository
- Check the [n8n documentation](https://docs.n8n.io/)
- Review [Supabase documentation](https://supabase.com/docs)

---

**Note**: This system is designed for automotive sales but can be adapted for other industries by modifying the database schema and workflow configuration.
