#!/bin/bash
set -e

PROJECT_NAME="${project_name}"
REGION="${region}"
BASTION_PUBLIC_KEY="${bastion_public_key}"

echo "🚀 Initializing Bastion Host for $PROJECT_NAME"

# Configure SSH authorized keys para el usuario ubuntu
UBUNTU_HOME="/home/ubuntu"
mkdir -p $UBUNTU_HOME/.ssh
chmod 700 $UBUNTU_HOME/.ssh
echo "$BASTION_PUBLIC_KEY" >> $UBUNTU_HOME/.ssh/authorized_keys
chmod 600 $UBUNTU_HOME/.ssh/authorized_keys
chown -R ubuntu:ubuntu $UBUNTU_HOME/.ssh

# Update system
apt-get update
apt-get install -y curl unzip jq postgresql-client awscli

# Install Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Verify installations
echo "✅ PostgreSQL client: $(psql --version)"
echo "✅ Node.js: $(node --version)"
echo "✅ npm: $(npm --version)"

# Create migrations directory
mkdir -p /opt/regaloshop/migrations
cd /opt/regaloshop

# Function to run migrations via SSH from GitHub Actions
cat > /opt/regaloshop/run-migrations.sh << 'SCRIPT'
#!/bin/bash

PROJECT_NAME="$1"
REGION="$2"

# Get credentials from Secrets Manager
echo "Fetching database credentials..."
SECRET=$(aws secretsmanager get-secret-value \
  --secret-id "$PROJECT_NAME-aurora-credentials" \
  --region "$REGION" \
  --query 'SecretString' \
  --output text)

DB_USER=$(echo "$SECRET" | jq -r '.username')
DB_PASSWORD=$(echo "$SECRET" | jq -r '.password')

# Get connection URL
DB_URL=$(aws secretsmanager get-secret-value \
  --secret-id "$PROJECT_NAME-aurora-url" \
  --region "$REGION" \
  --query 'SecretString' \
  --output text)

# Extract endpoint
DB_ENDPOINT=$(echo "$DB_URL" | grep -oP '(?<=@)[^:]+' || echo "")
DB_NAME=$(echo "$DB_URL" | grep -oP '(?<=/)[^/]+$' || echo "")

if [ -z "$DB_ENDPOINT" ]; then
  echo "❌ Could not extract database endpoint"
  exit 1
fi

echo "✅ Database endpoint: $DB_ENDPOINT"
echo "✅ Database name: $DB_NAME"

# Test connectivity
echo "Testing PostgreSQL connectivity..."
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_ENDPOINT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT NOW();" || {
  echo "❌ Failed to connect to Aurora"
  exit 1
}

echo "✅ Connected to Aurora"

# Execute SQL migrations from Regaloshop repo (if path is provided)
if [ $# -gt 2 ] && [ -n "$3" ]; then
  MIGRATIONS_PATH="$3"
  if [ -d "$MIGRATIONS_PATH" ]; then
    echo "🚀 Executing migrations from $MIGRATIONS_PATH..."
    for migration_file in $(find "$MIGRATIONS_PATH" -name "*.sql" -type f | sort); do
      echo "  ▶ Applying: $(basename $migration_file)"
      PGPASSWORD="$DB_PASSWORD" psql -h "$DB_ENDPOINT" -U "$DB_USER" -d "$DB_NAME" -f "$migration_file" || {
        echo "  ❌ Failed to apply migration: $(basename $migration_file)"
        exit 1
      }
    done
    echo "✅ All migrations applied successfully"
  else
    echo "⚠️  Migrations directory not found: $MIGRATIONS_PATH"
  fi
else
  echo "✅ No migrations to apply (call with migrations path as 3rd argument)"
fi

echo "✅ Migration script completed"
SCRIPT

chmod +x /opt/regaloshop/run-migrations.sh

# Create seed script
cat > /opt/regaloshop/run-seed.sh << 'SEED_SCRIPT'
#!/bin/bash

PROJECT_NAME="$1"
REGION="$2"
SEED_SCRIPT_PATH="$3"

# Get credentials from Secrets Manager
echo "Fetching database credentials..."
SECRET=$(aws secretsmanager get-secret-value \
  --secret-id "$PROJECT_NAME-aurora-credentials" \
  --region "$REGION" \
  --query 'SecretString' \
  --output text)

DB_USER=$(echo "$SECRET" | jq -r '.username')
DB_PASSWORD=$(echo "$SECRET" | jq -r '.password')

# Get connection URL
DB_URL=$(aws secretsmanager get-secret-value \
  --secret-id "$PROJECT_NAME-aurora-url" \
  --region "$REGION" \
  --query 'SecretString' \
  --output text)

# Extract endpoint
DB_ENDPOINT=$(echo "$DB_URL" | grep -oP '(?<=@)[^:]+' || echo "")
DB_NAME=$(echo "$DB_URL" | grep -oP '(?<=/)[^/]+$' || echo "")

if [ -z "$DB_ENDPOINT" ]; then
  echo "❌ Could not extract database endpoint"
  exit 1
fi

echo "✅ Database endpoint: $DB_ENDPOINT"
echo "✅ Database name: $DB_NAME"

# Test connectivity
echo "Testing PostgreSQL connectivity..."
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_ENDPOINT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT NOW();" || {
  echo "❌ Failed to connect to Aurora"
  exit 1
}

echo "✅ Connected to Aurora"

# Run Node.js seed script if provided
if [ -n "$SEED_SCRIPT_PATH" ] && [ -f "$SEED_SCRIPT_PATH" ]; then
  echo "🌱 Running seed script: $SEED_SCRIPT_PATH"
  
  # Create backend structure
  TEMP_BACKEND="/tmp/regaloshop-backend"
  mkdir -p "$TEMP_BACKEND"
  
  # Copy package files to temp backend
  if [ -f "/tmp/package.json" ]; then
    cp /tmp/package.json "$TEMP_BACKEND/"
    cp /tmp/package-lock.json "$TEMP_BACKEND/" 2>/dev/null || true
  fi
  
  # The src directory should already be in /tmp/regaloshop-backend/src (copied by workflow)
  # If not, we can copy from /tmp/src (backward compatibility)
  if [ ! -d "$TEMP_BACKEND/src" ] && [ -d "/tmp/src" ]; then
    cp -r /tmp/src "$TEMP_BACKEND/"
  fi
  
  # Ensure src/db and src/data directories exist
  mkdir -p "$TEMP_BACKEND/src/db"
  mkdir -p "$TEMP_BACKEND/src/data"
  
  # If pool.js doesn't exist, create a minimal version
  if [ ! -f "$TEMP_BACKEND/src/db/pool.js" ]; then
    echo "⚠️  pool.js not found, creating fallback..."
    cat > "$TEMP_BACKEND/src/db/pool.js" << 'POOL_JS'
const { Pool } = require('pg');

const poolConfig = {
  host: process.env.DB_HOST,
  port: process.env.DB_PORT || 5432,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
};

if (process.env.DB_SSL === 'true') {
  poolConfig.ssl = {
    rejectUnauthorized: process.env.DB_SSL_STRICT !== 'false',
  };
}

const pool = new Pool(poolConfig);

async function withTransaction(handler) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await handler(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

module.exports = { pool, withTransaction };
POOL_JS
  fi
  
  # The seed script should be in /tmp/regaloshop-backend/scripts/seedDatabase.js
  # Copy the seed script if provided as parameter
  if [ -n "$SEED_SCRIPT_PATH" ] && [ -f "$SEED_SCRIPT_PATH" ]; then
    mkdir -p "$TEMP_BACKEND/scripts"
    cp "$SEED_SCRIPT_PATH" "$TEMP_BACKEND/scripts/seedDatabase.js"
  fi
  
  # Change to backend directory (IMPORTANT: must be before npm install)
  cd "$TEMP_BACKEND"
  
  # Set database environment variables
  export DB_HOST="$DB_ENDPOINT"
  export DB_USER="$DB_USER"
  export DB_PASSWORD="$DB_PASSWORD"
  export DB_NAME="$DB_NAME"
  export DB_SSL=true
  export DB_SSL_STRICT=false
  
  # Install dependencies in the current directory
  echo "📦 Installing dependencies..."
  npm install --no-save 2>&1 | tail -5
  
  # Verify pg module is installed
  if [ ! -d "node_modules/pg" ]; then
    echo "⚠️  pg module not found, installing explicitly..."
    npm install pg --no-save
  fi
  
  # Run the seed script from scripts directory where require paths work correctly
  # When running node scripts/seedDatabase.js from /tmp/regaloshop-backend,
  # the require('../src/db/pool') will correctly resolve to /tmp/regaloshop-backend/src/db/pool
  echo "🌱 Loading seed data into database..."
  if [ -f "scripts/seedDatabase.js" ]; then
    node scripts/seedDatabase.js --truncate || {
      echo "❌ Seed script failed"
      exit 1
    }
  else
    echo "⚠️  scripts/seedDatabase.js not found at $(pwd)/scripts/seedDatabase.js"
    exit 1
  fi
  
  echo "✅ Seed script completed successfully"
else
  echo "⚠️  Seed script not found or not provided"
fi

echo "✅ Seed execution completed"
SEED_SCRIPT

chmod +x /opt/regaloshop/run-seed.sh

echo "✅ Bastion Host initialized successfully"
echo "📌 SSH Command: ssh -i <key.pem> ubuntu@<BASTION_IP>"
echo "📌 Run migrations: /opt/regaloshop/run-migrations.sh $PROJECT_NAME $REGION /path/to/migrations"
echo "📌 Run seed: /opt/regaloshop/run-seed.sh $PROJECT_NAME $REGION /path/to/seedDatabase.js"

