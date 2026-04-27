#!/bin/bash
set -e

echo "Wait for cloud-init to finish..."
cloud-init status --wait

echo "Installing prerequisite packages..."
sudo apt-get update -y
sudo apt-get install -y software-properties-common curl gnupg2 unzip

echo "Installing Docker..."
sudo apt-get install -y docker.io
sudo systemctl enable docker
sudo usermod -aG docker ubuntu

echo "Adding HashiCorp repository..."
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

echo "Installing Nomad and Consul..."
sudo apt-get update -y
sudo apt-get install -y nomad consul

echo "Setting up configuration directories..."
sudo mkdir -p /etc/nomad.d /etc/consul.d /opt/nomad /opt/consul
sudo chown -R nomad:nomad /etc/nomad.d /opt/nomad
sudo chown -R consul:consul /etc/consul.d /opt/consul

echo "Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh
sudo systemctl enable tailscaled

echo "Building statuspage binary..."
curl -fsSL https://go.dev/dl/go1.22.2.linux-amd64.tar.gz | sudo tar -C /usr/local -xzf -
export PATH=$PATH:/usr/local/go/bin
mkdir -p /tmp/statuspage-build
cp -r /tmp/app/* /tmp/statuspage-build/ 2>/dev/null || true
cd /tmp/statuspage-build
CGO_ENABLED=0 go build -o /usr/local/bin/statuspage .
chmod +x /usr/local/bin/statuspage
cd /
rm -rf /tmp/statuspage-build /usr/local/go

echo "Cleaning up..."
sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/*