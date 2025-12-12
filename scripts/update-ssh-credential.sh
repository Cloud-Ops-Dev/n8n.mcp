#!/bin/bash
# Updates the IBM VPC SSH Key credential hostname in n8n database
# Usage: ./update-ssh-credential.sh <new_ip_address>

NEW_IP=$1
CREDENTIAL_ID="c7OfsVIzconTwQgh"
ENCRYPTION_KEY="tmoe6lnXCkgJDlWj4AvQCXX9QDdMQIF2"

if [ -z "$NEW_IP" ]; then
  echo "Usage: $0 <new_ip_address>"
  exit 1
fi

# Create a temporary Node.js script that handles encryption
cat > /tmp/n8n-cred-update.js <<'ENDSCRIPT'
const crypto = require('crypto');

const ENCRYPTION_KEY = process.env.ENCRYPTION_KEY;
const encryptedData = process.env.ENCRYPTED_DATA;
const newIP = process.env.NEW_IP;

function evpKDF(password, salt, keySize) {
  const hashes = [];
  let hash = Buffer.alloc(0);
  while (Buffer.concat(hashes).length < keySize) {
    const data = Buffer.concat([hash, password, salt]);
    hash = crypto.createHash('md5').update(data).digest();
    hashes.push(hash);
  }
  return Buffer.concat(hashes).slice(0, keySize);
}

function decrypt(encryptedData, key) {
  const data = Buffer.from(encryptedData, 'base64');
  const salt = data.slice(8, 16);
  const encData = data.slice(16);
  const keyAndIV = evpKDF(Buffer.from(key), salt, 32 + 16);
  const aesKey = keyAndIV.slice(0, 32);
  const iv = keyAndIV.slice(32);
  const decipher = crypto.createDecipheriv('aes-256-cbc', aesKey, iv);
  let decrypted = decipher.update(encData);
  decrypted = Buffer.concat([decrypted, decipher.final()]);
  return decrypted.toString('utf8');
}

function encrypt(data, key) {
  const salt = crypto.randomBytes(8);
  const keyAndIV = evpKDF(Buffer.from(key), salt, 32 + 16);
  const aesKey = keyAndIV.slice(0, 32);
  const iv = keyAndIV.slice(32);
  const cipher = crypto.createCipheriv('aes-256-cbc', aesKey, iv);
  let encrypted = cipher.update(data, 'utf8');
  encrypted = Buffer.concat([encrypted, cipher.final()]);
  const salted = Buffer.concat([Buffer.from('Salted__'), salt, encrypted]);
  return salted.toString('base64');
}

try {
  const decrypted = decrypt(encryptedData, ENCRYPTION_KEY);
  const credData = JSON.parse(decrypted);
  console.error('Old hostname:', credData.host);
  credData.host = newIP;
  const newEncrypted = encrypt(JSON.stringify(credData), ENCRYPTION_KEY);
  console.log(newEncrypted);
  console.error('New hostname:', newIP);
} catch (error) {
  console.error('Error:', error.message);
  process.exit(1);
}
ENDSCRIPT

# Get current encrypted data from database
ENCRYPTED_DATA=$(docker exec n8n-postgres psql -U n8n -d n8n -t -c "SELECT data FROM credentials_entity WHERE id = '$CREDENTIAL_ID';" | tr -d ' \n')

if [ -z "$ENCRYPTED_DATA" ]; then
  echo "Error: Credential not found"
  exit 1
fi

# Decrypt, update, and re-encrypt
NEW_ENCRYPTED=$(ENCRYPTION_KEY="$ENCRYPTION_KEY" ENCRYPTED_DATA="$ENCRYPTED_DATA" NEW_IP="$NEW_IP" node /tmp/n8n-cred-update.js 2>&1)

# Check if encryption succeeded
if [ $? -ne 0 ]; then
  echo "Error during encryption:"
  echo "$NEW_ENCRYPTED"
  exit 1
fi

# Extract just the encrypted data (last line of output)
NEW_ENCRYPTED_DATA=$(echo "$NEW_ENCRYPTED" | tail -1)

# Update database
docker exec n8n-postgres psql -U n8n -d n8n -c "UPDATE credentials_entity SET data = '$NEW_ENCRYPTED_DATA', \"updatedAt\" = CURRENT_TIMESTAMP(3) WHERE id = '$CREDENTIAL_ID';" > /dev/null

if [ $? -eq 0 ]; then
  echo "✓ Updated IBM VPC SSH Key credential hostname to: $NEW_IP"
else
  echo "✗ Failed to update database"
  exit 1
fi

# Cleanup
rm -f /tmp/n8n-cred-update.js
