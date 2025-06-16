#!/bin/bash

# Domain list
domains=(
    "license.p2p1shop.ir"
    "license2.rocektserver.com"
    "license1.rocektserver.com"
    "licenseir.p2p1shop.ir"
)

# Directories
CERT_DIR="/root/back_certs"
CA_DIR="/usr/local/share/ca-certificates"
HOSTS_FILE="/etc/hosts"
TARGET_IP="127.0.0.2"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting SSL certificate setup for domains...${NC}"

# Create certificate directory if it doesn't exist
mkdir -p "$CERT_DIR"

# Function to create self-signed certificate
create_certificate() {
    local domain=$1
    local cert_file="${CERT_DIR}/${domain}.crt"
    local key_file="${CERT_DIR}/${domain}.key"
    local ca_cert_file="${CA_DIR}/${domain}.crt"
    
    # Check if certificate already exists
    if [[ -f "$cert_file" && -f "$key_file" ]]; then
        echo -e "${YELLOW}Certificate for $domain already exists, skipping...${NC}"
        return
    fi
    
    echo -e "${GREEN}Creating self-signed certificate for: $domain${NC}"
    
    # Create certificate configuration
    cat > "/tmp/${domain}.conf" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C=US
ST=State
L=City
O=Organization
OU=IT Department
CN=$domain

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $domain
DNS.2 = *.$domain
EOF
    
    # Generate private key
    openssl genrsa -out "$key_file" 2048
    
    # Generate certificate signing request
    openssl req -new -key "$key_file" -out "/tmp/${domain}.csr" -config "/tmp/${domain}.conf"
    
    # Generate self-signed certificate
    openssl x509 -req -in "/tmp/${domain}.csr" -signkey "$key_file" -out "$cert_file" -days 365 -extensions v3_req -extfile "/tmp/${domain}.conf"
    
    # Copy certificate to CA directory
    cp "$cert_file" "$ca_cert_file"
    
    # Set proper permissions
    chmod 644 "$cert_file" "$ca_cert_file"
    chmod 600 "$key_file"
    
    # Clean up temporary files
    rm -f "/tmp/${domain}.csr" "/tmp/${domain}.conf"
    
    echo -e "${GREEN}Certificate created for $domain${NC}"
}

# Function to update hosts file
update_hosts_file() {
    echo -e "${GREEN}Updating /etc/hosts file...${NC}"
    
    # Create backup of hosts file
    cp "$HOSTS_FILE" "${HOSTS_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Remove existing entries for our domains
    for domain in "${domains[@]}"; do
        sed -i "/[[:space:]]${domain}$/d" "$HOSTS_FILE"
        echo -e "${YELLOW}Removed existing entry for: $domain${NC}"
    done
    
    # Add new entries
    echo "" >> "$HOSTS_FILE"
    echo "# SSL Domain entries - Added $(date)" >> "$HOSTS_FILE"
    for domain in "${domains[@]}"; do
        echo "$TARGET_IP $domain" >> "$HOSTS_FILE"
        echo -e "${GREEN}Added: $TARGET_IP $domain${NC}"
    done
}

# Function to setup virtual IP
setup_virtual_ip() {
    echo -e "${GREEN}Setting up virtual IP: $TARGET_IP${NC}"
    
    # Check if IP already exists
    if ip addr show lo | grep -q "$TARGET_IP"; then
        echo -e "${YELLOW}Virtual IP $TARGET_IP already exists${NC}"
    else
        ip addr add ${TARGET_IP}/32 dev lo
        echo -e "${GREEN}Added virtual IP: $TARGET_IP${NC}"
    fi
}

# Function to setup iptables rules
setup_iptables() {
    echo -e "${GREEN}Setting up iptables rules...${NC}"
    
    # Check if rules already exist
    if iptables -t nat -L OUTPUT | grep -q "$TARGET_IP"; then
        echo -e "${YELLOW}iptables rules already exist, cleaning up first...${NC}"
        iptables -t nat -D OUTPUT -d $TARGET_IP -p tcp -j DNAT --to-destination 127.0.0.1:445 2>/dev/null || true
    fi
    
    # Add new rules
    iptables -t nat -A OUTPUT -d $TARGET_IP -p tcp -j DNAT --to-destination 127.0.0.1:445
    iptables -A INPUT -i lo -j ACCEPT 2>/dev/null || true
    iptables -A OUTPUT -o lo -j ACCEPT 2>/dev/null || true
    
    echo -e "${GREEN}iptables rules added${NC}"
}

# Main execution
echo -e "${GREEN}=== SSL Certificate and Domain Setup Script ===${NC}"
echo -e "${GREEN}Current time: $(date)${NC}"
echo -e "${GREEN}User: $(whoami)${NC}"
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root${NC}"
    exit 1
fi

# Check if openssl is installed
if ! command -v openssl &> /dev/null; then
    echo -e "${RED}OpenSSL is not installed. Installing...${NC}"
    apt-get update && apt-get install -y openssl
fi

# Create certificates for each domain
for domain in "${domains[@]}"; do
    create_certificate "$domain"
done

# Update CA certificates
echo -e "${GREEN}Updating CA certificates...${NC}"
update-ca-certificates

# Setup virtual IP
setup_virtual_ip

# Setup iptables
setup_iptables

# Update hosts file
update_hosts_file

echo
echo -e "${GREEN}=== Setup Complete ===${NC}"
echo -e "${GREEN}Certificates created in: $CERT_DIR${NC}"
echo -e "${GREEN}CA certificates added to: $CA_DIR${NC}"
echo -e "${GREEN}Hosts file updated: $HOSTS_FILE${NC}"
echo -e "${GREEN}Virtual IP configured: $TARGET_IP${NC}"
echo -e "${GREEN}iptables rules added${NC}"
echo
echo -e "${YELLOW}You can now test with:${NC}"
for domain in "${domains[@]}"; do
    echo -e "${YELLOW}  curl https://$domain/heartbeat${NC}"
done
echo
echo -e "${YELLOW}To remove setup, run:${NC}"
echo -e "${YELLOW}  ip addr del ${TARGET_IP}/32 dev lo${NC}"
echo -e "${YELLOW}  iptables -t nat -D OUTPUT -d $TARGET_IP -p tcp -j DNAT --to-destination 127.0.0.1:445${NC}"
echo -e "${YELLOW}  Restore /etc/hosts from backup${NC}"