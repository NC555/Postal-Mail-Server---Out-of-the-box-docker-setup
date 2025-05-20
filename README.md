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
      - '25:25'
      - '465:465'
      - '587:587'
      - '5000:5000'
    volumes:
      # If /data/postal/postal.yml exists and is configured, it will override ENV vars for DB etc.
      # Ensure it's correctly configured or remove this line to rely solely on ENV vars.
      - /data/postal/postal.yml:/config/postal.yml
      - postal_data:/opt/postal/storage # For persistent mail data
    environment:
      # General Postal Settings
      POSTAL_WEB_HOSTNAME: ${POSTAL_DOMAIN} # Official name
      POSTAL_WEB_PROTOCOL: https
      POSTAL_SMTP_HOSTNAME: ${POSTAL_DOMAIN} # Official name
      # POSTAL_SYSTEM_HOSTNAME: ${POSTAL_DOMAIN} # This was used before, POSTAL_WEB_HOSTNAME and POSTAL_SMTP_HOSTNAME are more specific from the list.
                                                # Postal's internal scripts might use one to derive others if not all are set.
                                                # Keeping POSTAL_WEB_HOSTNAME and POSTAL_SMTP_HOSTNAME as per official list.

      # Database Connection - Using official MAIN_DB_* prefixes
      MAIN_DB_HOST: ${MARIADB_CONTAINER}
      MAIN_DB_PORT: ${MARIADB_PORT} # CRITICAL: Ensure this is 3306 in your .env file
      MAIN_DB_DATABASE: postal
      MAIN_DB_USERNAME: ${MARIADB_USER}
      MAIN_DB_PASSWORD: ${MARIADB_PASSWORD}
      # MAIN_DB_POOL_SIZE: 5 # Optional: as per official list default
      # MAIN_DB_ENCODING: utf8mb4 # Optional: as per official list default

      # RabbitMQ Connection (Assuming these POSTAL_ prefixed vars are handled by Postal's image scripts)
      # The official list doesn't explicitly state how Postal consumes these for its connection TO RabbitMQ.
      # If issues persist, these might need to be mapped to different underlying library variables if Postal doesn't translate them.
      POSTAL_RABBITMQ_HOST: postal-rabbitmq
      POSTAL_RABBITMQ_USERNAME: ${RABBITMQ_USER} # Note: RabbitMQ service uses RABBITMQ_DEFAULT_USER
      POSTAL_RABBITMQ_PASSWORD: ${RABBITMQ_PASSWORD} # Note: RabbitMQ service uses RABBITMQ_DEFAULT_PASS
      POSTAL_RABBITMQ_VHOST: /postal

      # Rails Secret Key
      RAILS_SECRET_KEY: ${RANDOM_STRING} # Official name

      # Other settings from your previous compose (review if needed against official list)
      POSTAL_SMTP_PORT: 25 # This refers to the port Postal's SMTP server listens on, not an outbound SMTP relay.
                           # Official list has SMTP_SERVER_DEFAULT_PORT which defaults to 25.

    entrypoint: |
      bash -c '
      echo "Waiting for RabbitMQ..."
      while ! nc -z postal-rabbitmq 5672; do sleep 1; done
      echo "Waiting for MariaDB..."
      while ! nc -z ${MARIADB_CONTAINER} ${MARIADB_PORT}; do sleep 1; done # MARIADB_PORT should be 3306
      echo "Running database initialization..."
      if [ -f /config/postal.yml ]; then
        echo "INFO: Found /config/postal.yml. Settings from this file will take precedence over environment variables for conflicting keys."
      else
        echo "INFO: No /config/postal.yml found. Relying on environment variables for configuration."
      fi
      postal initialize || exit 1
      echo "Starting web server..."
      postal web-server'
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000"]
      interval: 30s
      timeout: 10s
      retries: 3
    depends_on:
      - postal-rabbitmq

  postal-worker:
    image: ghcr.io/postalserver/postal:latest
    container_name: postal-worker
    restart: always
    networks:
      - coolify
    volumes: # Worker might also benefit from postal.yml if it needs shared config
      - /data/postal/postal.yml:/config/postal.yml
    environment:
      # General Postal Settings
      POSTAL_WEB_HOSTNAME: ${POSTAL_DOMAIN}
      POSTAL_WEB_PROTOCOL: https
      POSTAL_SMTP_HOSTNAME: ${POSTAL_DOMAIN}

      # Database Connection - Using official MAIN_DB_* prefixes
      MAIN_DB_HOST: ${MARIADB_CONTAINER}
      MAIN_DB_PORT: ${MARIADB_PORT} # CRITICAL: Ensure this is 3306 in your .env file
      MAIN_DB_DATABASE: postal
      MAIN_DB_USERNAME: ${MARIADB_USER}
      MAIN_DB_PASSWORD: ${MARIADB_PASSWORD}

      # RabbitMQ Connection
      POSTAL_RABBITMQ_HOST: postal-rabbitmq
      POSTAL_RABBITMQ_USERNAME: ${RABBITMQ_USER}
      POSTAL_RABBITMQ_PASSWORD: ${RABBITMQ_PASSWORD}
      POSTAL_RABBITMQ_VHOST: /postal

      # Rails Secret Key
      RAILS_SECRET_KEY: ${RANDOM_STRING}

      POSTAL_SMTP_PORT: 25

    entrypoint: |
      bash -c '
      echo "Waiting for postal web (main postal service)..."
      while ! nc -z postal 5000; do sleep 1; done
      echo "Waiting for RabbitMQ..."
      while ! nc -z postal-rabbitmq 5672; do sleep 1; done
      echo "Waiting for MariaDB..."
      while ! nc -z ${MARIADB_CONTAINER} ${MARIADB_PORT}; do sleep 1; done # MARIADB_PORT should be 3306
      if [ -f /config/postal.yml ]; then
        echo "INFO (worker): Found /config/postal.yml."
      else
        echo "INFO (worker): No /config/postal.yml found. Relying on environment variables."
      fi
      echo "Starting worker..."
      postal worker'
    depends_on:
      - postal # Depends on the main postal service to be somewhat up
      - postal-rabbitmq # Also directly depends on rabbitmq

  postal-rabbitmq:
    image: rabbitmq:3.8-management # Consider updating to a more recent RabbitMQ version if compatible
    container_name: postal-rabbitmq
    networks:
      - coolify
    volumes:
      - postal_rabbitmq_data:/var/lib/rabbitmq
    environment:
      RABBITMQ_DEFAULT_USER: ${RABBITMQ_USER} # Use the var from .env
      RABBITMQ_DEFAULT_PASS: ${RABBITMQ_PASSWORD} # Use the var from .env
      RABBITMQ_DEFAULT_VHOST: /postal # Postal expects this vhost
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "check_port_connectivity"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  coolify:
    external: true

volumes:
  # postal_config: # This named volume is not used if you map a host path for postal.yml
  postal_data:
  postal_rabbitmq_data:
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
