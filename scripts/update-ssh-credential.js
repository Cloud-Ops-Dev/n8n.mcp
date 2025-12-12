#!/usr/bin/env node
/**
 * Updates the IBM VPC SSH Key credential hostname in n8n database
 * Usage: node update-ssh-credential.js <new_ip_address>
 */

const { Client } = require('pg');
const crypto = require('crypto');

// Configuration
const CREDENTIAL_ID = 'c7OfsVIzconTwQgh';
const CREDENTIAL_NAME = 'IBM VPC SSH Key';
const ENCRYPTION_KEY = 'tmoe6lnXCkgJDlWj4AvQCXX9QDdMQIF2';

const DB_CONFIG = {
  host: 'localhost',
  port: 5432,
  user: 'n8n',
  password: 'changeme_secure_password',
  database: 'n8n'
};

// n8n uses crypto-js style encryption (AES)
function decrypt(encryptedData, key) {
  // Parse "Salted__" format
  const data = Buffer.from(encryptedData, 'base64');
  const salt = data.slice(8, 16);
  const encData = data.slice(16);

  // Derive key and IV using MD5 (same as crypto-js)
  const keyAndIV = evpKDF(Buffer.from(key), salt, 32 + 16);
  const aesKey = keyAndIV.slice(0, 32);
  const iv = keyAndIV.slice(32);

  // Decrypt
  const decipher = crypto.createDecipheriv('aes-256-cbc', aesKey, iv);
  let decrypted = decipher.update(encData);
  decrypted = Buffer.concat([decrypted, decipher.final()]);

  return decrypted.toString('utf8');
}

function encrypt(data, key) {
  // Generate salt
  const salt = crypto.randomBytes(8);

  // Derive key and IV
  const keyAndIV = evpKDF(Buffer.from(key), salt, 32 + 16);
  const aesKey = keyAndIV.slice(0, 32);
  const iv = keyAndIV.slice(32);

  // Encrypt
  const cipher = crypto.createCipheriv('aes-256-cbc', aesKey, iv);
  let encrypted = cipher.update(data, 'utf8');
  encrypted = Buffer.concat([encrypted, cipher.final()]);

  // Prepend "Salted__" + salt
  const salted = Buffer.concat([
    Buffer.from('Salted__'),
    salt,
    encrypted
  ]);

  return salted.toString('base64');
}

// EVP_BytesToKey implementation (same as crypto-js)
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

async function updateCredential(newIP) {
  const client = new Client(DB_CONFIG);

  try {
    await client.connect();

    // Get current credential data
    const result = await client.query(
      'SELECT data FROM credentials_entity WHERE id = $1',
      [CREDENTIAL_ID]
    );

    if (result.rows.length === 0) {
      throw new Error(`Credential not found: ${CREDENTIAL_NAME}`);
    }

    // Decrypt
    const encryptedData = result.rows[0].data;
    const decrypted = decrypt(encryptedData, ENCRYPTION_KEY);
    const credData = JSON.parse(decrypted);

    console.log('Current hostname:', credData.host);

    // Update hostname
    credData.host = newIP;

    // Re-encrypt
    const newEncrypted = encrypt(JSON.stringify(credData), ENCRYPTION_KEY);

    // Update database
    await client.query(
      'UPDATE credentials_entity SET data = $1, "updatedAt" = CURRENT_TIMESTAMP(3) WHERE id = $2',
      [newEncrypted, CREDENTIAL_ID]
    );

    console.log('✓ Updated hostname to:', newIP);
    console.log('✓ Credential updated successfully');

  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

// Main
const newIP = process.argv[2];

if (!newIP) {
  console.error('Usage: node update-ssh-credential.js <new_ip_address>');
  process.exit(1);
}

updateCredential(newIP);
