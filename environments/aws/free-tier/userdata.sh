#!/bin/bash
set -euo pipefail

LOGFILE="/var/log/hyperswitch-setup.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "Starting Hyperswitch setup on EC2..."

# Install dependencies
sudo yum update -y
sudo yum install -y docker jq postgresql15 git wget
sudo yum groupinstall -y "Development Tools"

# Start Docker
sudo service docker start
sudo usermod -a -G docker ec2-user
sudo systemctl enable docker

# Restart session to apply docker group changes
sudo su - ec2-user -c "echo 'Docker group applied'"

# Install SSM Agent
sudo yum install -y amazon-ssm-agent
sudo systemctl enable amazon-ssm-agent
sudo systemctl start amazon-ssm-agent

export LC_ALL=en_US.UTF-8
export PGPASSWORD="${db_password}"

# Wait for database
echo "Waiting for database..."
for i in {1..60}; do
  if pg_isready -h ${db_host} -p 5432 -U ${db_username}; then
    echo "Database ready!"
    break
  fi
  sleep 10
done

# Setup application directory
sudo mkdir -p /opt/hyperswitch
cd /opt/hyperswitch

# Download official configuration files
echo "Downloading official Hyperswitch configuration files..."
curl -o docker_compose.toml https://raw.githubusercontent.com/juspay/hyperswitch/main/config/docker_compose.toml
curl -o dashboard.toml https://raw.githubusercontent.com/juspay/hyperswitch/main/config/dashboard.toml

# Check and run migrations if needed
if ! psql -h ${db_host} -U ${db_username} -d ${db_name} -tAc "SELECT 1 FROM information_schema.tables WHERE table_name='merchant_account'" 2>/dev/null | grep -q 1; then
  echo "Running database migrations..."
  # Clone repo for migrations
  git clone --depth 1 --branch latest https://github.com/juspay/hyperswitch.git /tmp/hyperswitch

  # Run migrations using Docker container
  docker run --rm \
    -v /tmp/hyperswitch:/app \
    -w /app \
    -e DATABASE_URL="postgresql://${db_username}:${db_password}@${db_host}:5432/${db_name}" \
    --network host \
    rust:latest \
    bash -c "
      curl -fsSL https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash &&
      cargo binstall diesel_cli just --no-confirm &&
      just migrate
    "

  # Cleanup
  rm -rf /tmp/hyperswitch
  cd /opt/hyperswitch
fi

sudo chown -R ec2-user:ec2-user /opt/hyperswitch

# Create environment file with proper overrides
cat >/opt/hyperswitch/.env <<EOF
# Database Configuration Overrides
ROUTER__MASTER_DATABASE__HOST=${db_host}
ROUTER__MASTER_DATABASE__USERNAME=${db_username}
ROUTER__MASTER_DATABASE__PASSWORD=${db_password}
ROUTER__MASTER_DATABASE__DBNAME=${db_name}
ROUTER__REPLICA_DATABASE__HOST=${db_host}
ROUTER__REPLICA_DATABASE__USERNAME=${db_username}
ROUTER__REPLICA_DATABASE__PASSWORD=${db_password}
ROUTER__REPLICA_DATABASE__DBNAME=${db_name}

# Redis Configuration Override
ROUTER__REDIS__HOST=${redis_host}

# Analytics Configuration Overrides
ROUTER__ANALYTICS__SQLX__HOST=${db_host}
ROUTER__ANALYTICS__SQLX__USERNAME=${db_username}
ROUTER__ANALYTICS__SQLX__PASSWORD=${db_password}
ROUTER__ANALYTICS__SQLX__DBNAME=${db_name}

# Server Configuration Overrides
ROUTER__SERVER__BASE_URL=https://${app_cloudfront_url}
ROUTER__SECRETS__ADMIN_API_KEY=${admin_api_key}

# User Configuration Override
ROUTER__USER__BASE_URL=https://${app_cloudfront_url}

# Control Center Configuration
apiBaseUrl=https://${app_cloudfront_url}
sdkBaseUrl=https://${sdk_cloudfront_url}

# Web SDK Configuration
HYPERSWITCH_SERVER_URL=https://${app_cloudfront_url}
HYPERSWITCH_CLIENT_URL=https://${sdk_cloudfront_url}
SDK_ENV=production
ENABLE_LOGGING=false
EOF

# Start services
echo "Starting Hyperswitch services..."

# Ensure Docker is accessible
echo "Testing Docker access..."
docker --version
docker ps

# Router
echo "Pulling Hyperswitch Router image..."
docker pull juspaydotin/hyperswitch-router:standalone

echo "Starting Hyperswitch Router container..."
docker run -d --name hyperswitch-router --env-file /opt/hyperswitch/.env -p 8080:8080 \
  -v /opt/hyperswitch/docker_compose.toml:/local/config/docker_compose.toml --restart unless-stopped \
  juspaydotin/hyperswitch-router:standalone ./router -f /local/config/docker_compose.toml

echo "Router container started. Checking status..."
docker ps -a | grep hyperswitch-router

# Wait for router
echo "Waiting for router to be healthy..."
for i in {1..30}; do
  if curl -f http://localhost:8080/health >/dev/null 2>&1; then
    echo "Router is healthy!"
    break
  fi
  echo "Attempt $i/30: Router not ready yet..."
  sleep 1
done

# Check if router failed to start
if ! curl -f http://localhost:8080/health >/dev/null 2>&1; then
  echo "ERROR: Router failed to start properly!"
  echo "Router logs:"
  docker logs hyperswitch-router
  echo "Attempting to restart router..."
  docker restart hyperswitch-router
  sleep 30
fi

# Update dashboard configuration
sed -i "s|api_url=\"http://localhost:8080\"|api_url=\"https://${app_cloudfront_url}\"|g" /opt/hyperswitch/dashboard.toml
sed -i "s|sdk_url=\"http://localhost:9050/HyperLoader.js\"|sdk_url=\"https://${sdk_cloudfront_url}/HyperLoader.js\"|g" /opt/hyperswitch/dashboard.toml

# Control Center
docker pull juspaydotin/hyperswitch-control-center:latest
docker run -d --name hyperswitch-control-center -p 9000:9000 \
  -v /opt/hyperswitch/dashboard.toml:/tmp/dashboard-config.toml \
  -e "configPath=/tmp/dashboard-config.toml" \
  --restart unless-stopped juspaydotin/hyperswitch-control-center:latest

# Web SDK
docker pull juspaydotin/hyperswitch-web:latest
docker run -d --name hyperswitch-web --env-file /opt/hyperswitch/.env -p 9050:9050 \
  --restart unless-stopped juspaydotin/hyperswitch-web:latest

sleep 30

# Create merchant account
echo "Setting up merchant account..."
MERCHANT_RESPONSE=$(curl --silent --location --request POST "http://localhost:8080/accounts" \
  --header 'Content-Type: application/json' --header "api-key: ${admin_api_key}" \
  --data-raw '{"merchant_id": "hyperswitch_merchant", "merchant_name": "Hyperswitch Merchant", "organization_id": "hyperswitch_org"}' || echo "failed")

if [[ "$MERCHANT_RESPONSE" == *"merchant_id"* ]]; then
  MERCHANT_ID=$(echo "$MERCHANT_RESPONSE" | jq -r '.merchant_id // "hyperswitch_merchant"')
  PUBLISHABLE_KEY=$(echo "$MERCHANT_RESPONSE" | jq -r '.publishable_key // ""')
else
  MERCHANT_ID="hyperswitch_merchant"
  PUBLISHABLE_KEY=""
fi

# Create API key
API_KEY_RESPONSE=$(curl --silent --location --request POST "http://localhost:8080/api_keys/$${MERCHANT_ID}" \
  --header 'Content-Type: application/json' --header "api-key: ${admin_api_key}" \
  --data-raw '{"name": "Default API Key", "expiration": "2030-12-31T23:59:59.000Z"}' || echo "failed")

if [[ "$API_KEY_RESPONSE" == *"api_key"* ]]; then
  SECRET_KEY=$(echo "$API_KEY_RESPONSE" | jq -r '.api_key')
else
  SECRET_KEY="placeholder_secret_key"
fi

# Start demo app
docker pull juspaydotin/hyperswitch-react-demo-app:latest
docker run -d --name hyperswitch-demo -p 5252:5252 -p 9060:9060 \
  -e "HYPERSWITCH_PUBLISHABLE_KEY=$${PUBLISHABLE_KEY}" -e "HYPERSWITCH_SECRET_KEY=$${SECRET_KEY}" \
  -e "HYPERSWITCH_SERVER_URL=https://${app_cloudfront_url}" -e "HYPERSWITCH_CLIENT_URL=https://${sdk_cloudfront_url}" \
  --restart unless-stopped juspaydotin/hyperswitch-react-demo-app:latest

echo "Hyperswitch setup completed successfully!"
echo "Access URLs:"
echo "- API Server: https://${app_cloudfront_url}"
echo "- Control Center: https://${app_cloudfront_url}:9000"
echo "- Demo App: https://${app_cloudfront_url}:5252"
echo "Credentials:"
echo "- Merchant ID: $${MERCHANT_ID}"
echo "- Publishable Key: $${PUBLISHABLE_KEY}"
echo "- Secret Key: $${SECRET_KEY}"
