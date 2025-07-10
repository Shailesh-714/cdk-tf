#!/bin/bash
set -euo pipefail

LOGFILE="/var/log/hyperswitch-frontend-setup.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "Starting Hyperswitch Frontend setup (SDK + Demo App)..."

# Add swap space for t2.micro
echo "Adding swap space..."
sudo dd if=/dev/zero of=/swapfile bs=128M count=16
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile swap swap defaults 0 0' | sudo tee -a /etc/fstab

# Install dependencies
sudo yum update -y
sudo yum install -y docker jq

# Start Docker
sudo service docker start
sudo usermod -a -G docker ec2-user
sudo systemctl enable docker

# Install SSM Agent
sudo yum install -y amazon-ssm-agent
sudo systemctl enable amazon-ssm-agent
sudo systemctl start amazon-ssm-agent

# Setup application directory
sudo mkdir -p /opt/hyperswitch
cd /opt/hyperswitch

# Note: Frontend doesn't need direct backend access since it goes through ALB/CloudFront
echo "Frontend instance starting..."

# Use the CloudFront URLs for API access
API_URL="https://${app_cloudfront_url}"
SDK_URL="https://${sdk_cloudfront_url}"
echo "API URL: $API_URL"
echo "SDK URL: $SDK_URL"

# Create environment file for SDK
cat >/opt/hyperswitch/.env <<EOF
# Web SDK Configuration
ENV_BACKEND_URL=$API_URL
HYPERSWITCH_SERVER_URL=$API_URL
HYPERSWITCH_CLIENT_URL=$SDK_URL
SDK_ENV=production
ENABLE_LOGGING=false
# Allow CloudFront domain
ALLOWED_HOSTS=*
HOST=0.0.0.0
EOF

sudo chown -R ec2-user:ec2-user /opt/hyperswitch

# Start services
echo "Starting Hyperswitch frontend services..."

# Web SDK with memory limit
echo "Starting Web SDK..."
docker pull juspaydotin/hyperswitch-web:latest
docker run -d --name hyperswitch-web \
    --memory="384m" \
    --memory-swap="768m" \
    --env-file /opt/hyperswitch/.env \
    -p 9050:9050 \
    --restart unless-stopped \
    -w /usr/src/app \
    juspaydotin/hyperswitch-web:latest \
    /bin/sh -c "cd dist && python3 -m http.server 9050 --bind 0.0.0.0"

# Wait for SDK to be ready
echo "Waiting for SDK to be healthy..."
for i in {1..60}; do
    if curl -f http://localhost:9050/HyperLoader.js >/dev/null 2>&1; then
        echo "SDK is ready!"
        break
    fi
    echo "Attempt $i/60: SDK not ready yet..."
    sleep 5
done

echo "Frontend setup completed successfully!"
echo "Services running:"
echo "- Web SDK: http://localhost:9050"
echo "Access URLs:"
echo "- SDK URL: $SDK_URL/HyperLoader.js"
echo ""
