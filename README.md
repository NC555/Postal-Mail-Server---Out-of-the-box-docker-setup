# Postal Mail Server Setup Guide

## Prerequisites
- A VPS with Docker installed
- Domain name with DNS access
- Existing MariaDB container
- Nginx Proxy Manager
- Coolify network

## 1. DNS Configuration
Add these records in your DNS provider (e.g., Cloudflare):

```
# A Records
postal    A     → Your-VPS-IP
mx1       A     → Your-VPS-IP
mx2       A     → Your-VPS-IP

# CNAME Record
track     CNAME → postal.yourdomain.com

# MX Records
@         MX    → Priority 10 mx1.yourdomain.com
@         MX    → Priority 20 mx2.yourdomain.com
```

## 2. Environment Variables
Create a `.env` file with these variables:
```env
POSTAL_DOMAIN=postal.yourdomain.com
MARIADB_CONTAINER=your-mariadb-container-name
MARIADB_PORT=3306
MARIADB_USER=postal
MARIADB_PASSWORD=your-secure-password
RABBITMQ_USER=postal
RABBITMQ_PASSWORD=your-secure-rabbitmq-password
RANDOM_STRING=generate-a-random-string-here
```

## 3. Database Setup
Connect to your MariaDB container and run:
```sql
CREATE DATABASE postal;
CREATE USER 'postal'@'%' IDENTIFIED BY 'your-secure-password';
GRANT ALL PRIVILEGES ON postal.* TO 'postal'@'%';
FLUSH PRIVILEGES;
```

## 4. Docker Deployment
Docker compose file (as provided in your setup):
```yaml
version: '3'
services:
  postal:
    image: ghcr.io/postalserver/postal:latest
    container_name: postal
    restart: always
    networks:
      - coolify
    ports:
      - '25:25'      # SMTP
      - '465:465'    # SMTPS
      - '587:587'    # SMTP Submission
      - '5000:5000'  # Web Interface
    environment:
      - POSTAL_SYSTEM_HOSTNAME='${POSTAL_DOMAIN}'
      - POSTAL_SMTP_HOST='${POSTAL_DOMAIN}'
      - POSTAL_SMTP_PORT=25
      - POSTAL_DATABASE_HOST='${MARIADB_CONTAINER}'
      - POSTAL_DATABASE_PORT='${MARIADB_PORT}'
      - POSTAL_DATABASE_NAME=postal
      - POSTAL_DATABASE_USERNAME='${MARIADB_USER}'
      - POSTAL_DATABASE_PASSWORD='${MARIADB_PASSWORD}'
      - POSTAL_RABBITMQ_HOST=postal-rabbitmq
      - POSTAL_RABBITMQ_USERNAME='${RABBITMQ_USER}'
      - POSTAL_RABBITMQ_PASSWORD='${RABBITMQ_PASSWORD}'
      - POSTAL_RABBITMQ_VHOST=/postal
      - POSTAL_WEB_HOST='${POSTAL_DOMAIN}'
      - POSTAL_WEB_PROTOCOL=https
      - POSTAL_RAILS_SECRET='${RANDOM_STRING}'
    depends_on:
      - postal-rabbitmq

  postal-rabbitmq:
    image: rabbitmq:3.8-management
    container_name: postal-rabbitmq
    networks:
      - coolify
    environment:
      - RABBITMQ_DEFAULT_USER=postal
      - RABBITMQ_DEFAULT_PASS='${RABBITMQ_PASSWORD}'
      - RABBITMQ_DEFAULT_VHOST=/postal

networks:
  coolify:
    external: true
```

## 5. Nginx Proxy Manager Setup
Add new proxy host:
- Domain: postal.yourdomain.com
- Scheme: http
- Forward IP/host: postal
- Port: 5000
- Enable SSL and force SSL

## 6. Initialize Postal
After deployment:
```bash
# Access the postal container
docker exec -it postal bash

# Initialize postal
postal initialize

# Create admin user
postal make-user
```

## 7. Admin Console Setup & Configuration

### 7.1 First Login
1. Access `https://postal.yourdomain.com`
2. Login with credentials created during `postal make-user`

### 7.2 Configure IP Pools
1. Go to Settings → IP Pools
2. Add your VPS IP
3. Configure provided SPF and DKIM records in your DNS

### 7.3 Setup Click & Open Tracking
1. Navigate to Settings → Tracking
2. Enable click and open tracking
3. Verify track.yourdomain.com configuration

### 7.4 Configure SMTP
1. Go to Organizations → Your Organization
2. Create new Credential Pair
3. Save SMTP username and password

### 7.5 Configure Anti-spam
1. Go to Settings → Spam & Virus
2. Enable SpamAssassin if needed
3. Configure spam thresholds

## 8. Testing

### 8.1 Test SMTP Connection
```bash
telnet postal.yourdomain.com 25
```

### 8.2 Test Email Sending
```bash
# Using swaks
swaks --to test@example.com \
      --from your@yourdomain.com \
      --server postal.yourdomain.com \
      --auth-user smtp_username \
      --auth-password smtp_password
```

## 9. Maintenance

### 9.1 Logs
```bash
# View postal logs
docker logs postal

# View RabbitMQ logs
docker logs postal-rabbitmq
```

### 9.2 Backup
Regular backup of:
- MariaDB database
- Postal configuration
- SSL certificates

## 10. Security Recommendations
1. Use strong passwords
2. Keep ports 25, 465, and 587 secured
3. Regularly update DNS records
4. Monitor spam scores
5. Regularly check logs for suspicious activity

## 11. Troubleshooting
Common issues and solutions:
1. Cannot connect to database:
   - Check MariaDB credentials
   - Verify network connectivity
2. Email not sending:
   - Check SMTP credentials
   - Verify port accessibility
   - Check DNS records
3. Web interface not accessible:
   - Verify Nginx Proxy Manager configuration
   - Check SSL certificate status

Need help? Check:
- Postal documentation
- Container logs
- Database logs
- RabbitMQ management interface
