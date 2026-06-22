# IRIS Glaucoma MVP - Production Deployment Guide

**Version:** 1.0.0  
**Last Updated:** June 16, 2026  
**Status:** Production Ready

---

## Table of Contents

1. [Pre-Deployment Checklist](#pre-deployment-checklist)
2. [Backend Setup](#backend-setup)
3. [Deployment on Render](#deployment-on-render)
4. [Deployment on Railway](#deployment-on-railway)
5. [Deployment on AWS EC2](#deployment-on-aws-ec2)
6. [Flutter Configuration](#flutter-configuration)
7. [Monitoring & Logging](#monitoring--logging)
8. [Troubleshooting](#troubleshooting)

---

## Pre-Deployment Checklist

### Backend Readiness
- [ ] Model file (`best_model_epoch4.pth`) is available
- [ ] Python dependencies in `requirements.txt` are current
- [ ] `.env.example` is configured for your environment
- [ ] `main_production.py` has been tested locally
- [ ] Dockerfile builds successfully: `docker build -t iris-api:latest ./backend`
- [ ] Docker image runs locally: `docker run -p 8000:8000 iris-api:latest`

### Firebase Configuration
- [ ] Firebase project created and authenticated
- [ ] Firestore database initialized
- [ ] Security rules configured (see below)
- [ ] Firebase service account JSON ready

### Flutter Configuration
- [ ] `lib/services/api_config.dart` has production URL set
- [ ] Firebase credentials configured
- [ ] `pubspec.yaml` dependencies verified

### Hosting Provider Account
- [ ] Render, Railway, or AWS account created
- [ ] Payment method configured
- [ ] Free tier or budget monitoring enabled

---

## Backend Setup

### Local Testing

1. **Install dependencies:**
   ```bash
   cd backend
   pip install -r requirements.txt
   ```

2. **Create `.env` file from example:**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

3. **Run locally:**
   ```bash
   # Development
   python main.py
   
   # Production-like
   python main_production.py
   ```

4. **Test endpoints:**
   ```bash
   # Health check
   curl http://localhost:8000/health
   
   # API info
   curl http://localhost:8000/info
   
   # Prediction (requires image)
   curl -X POST -H "Authorization: Bearer valid_token_for_test" \
     -F "image=@/path/to/image.jpg" \
     http://localhost:8000/predict
   ```

### Docker Testing

1. **Build image:**
   ```bash
   docker build -t iris-api:latest ./backend
   ```

2. **Run container:**
   ```bash
   docker run -p 8000:8000 \
     -e ENVIRONMENT=development \
     -e MODEL_PATH=ml/models/best_model_epoch4.pth \
     iris-api:latest
   ```

3. **Test with docker-compose:**
   ```bash
   docker-compose up -d
   curl http://localhost:8000/health
   docker-compose down
   ```

---

## Deployment on Render

### Step 1: Prepare Repository

Render can deploy directly from GitHub. Ensure your repo structure is:
```
IRIS/
├── backend/
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── main_production.py
│   ├── .env.example
│   └── ml/
│       └── models/
│           └── best_model_epoch4.pth
├── docker-compose.yml
└── .gitignore
```

### Step 2: Create Web Service on Render

1. **Go to** https://dashboard.render.com
2. **Click** "New +" → "Web Service"
3. **Connect GitHub repo** with IRIS project
4. **Configure:**
   - Name: `iris-glaucoma-api`
   - Environment: `Docker`
   - Root Directory: `./backend` (or leave blank if Dockerfile at root)
   - Branch: `main` (or your branch)

### Step 3: Set Environment Variables

In Render dashboard, set:

```
ENVIRONMENT=production
API_HOST=0.0.0.0
API_PORT=8000
API_WORKERS=4
CORS_ORIGINS=https://your-app.com,https://your-cdn.com
MODEL_PATH=ml/models/best_model_epoch4.pth
DEVICE=auto
LOG_LEVEL=INFO
LOG_FORMAT=json
AUTH_ENABLED=true
AUTH_PROVIDER=firebase
INFERENCE_TIMEOUT_SECONDS=30
MAX_FILE_SIZE_MB=50
```

### Step 4: Configure Health Check

- Path: `/health`
- Check interval: 30 seconds
- Timeout: 10 seconds

### Step 5: Deploy

1. Click "Deploy"
2. Monitor build logs
3. Wait for "Live" status
4. Access at `https://iris-glaucoma-api.onrender.com`

### Step 6: Update Flutter

In `lib/services/api_config.dart`:
```dart
static const String productionRender = 'https://iris-glaucoma-api.onrender.com';
```

### Render Considerations

- **Free tier:** 15-minute deploy timeout, spins down after 15 minutes of inactivity
- **Paid tier:** Always-on, auto-scaling, better performance
- **File uploads:** Limited to available disk (not recommended for large models)

---

## Deployment on Railway

### Step 1: Create Railway Account

- Go to https://railway.app
- Sign up with GitHub account

### Step 2: Create New Project

1. **Click** "New Project"
2. **Select** "Deploy from GitHub repo"
3. **Choose** your IRIS repository
4. **Select** `backend/` directory

### Step 3: Configure Service

1. **Go to** Service settings
2. **Set Build Command:**
   ```
   pip install -r requirements.txt
   ```

3. **Set Start Command:**
   ```
   gunicorn main_production:app --workers 4 --worker-class uvicorn.workers.UvicornWorker --bind 0.0.0.0:$PORT
   ```

4. **Expose Port:** `8000`

### Step 4: Add Environment Variables

In Railway variables section:

```
ENVIRONMENT=production
API_HOST=0.0.0.0
API_PORT=8000
API_WORKERS=4
CORS_ORIGINS=https://your-app.com
MODEL_PATH=ml/models/best_model_epoch4.pth
DEVICE=auto
LOG_LEVEL=INFO
```

### Step 5: Deploy

1. Click "Deploy"
2. Monitor logs
3. Get public URL from Railway dashboard

### Step 6: Update Flutter

```dart
static const String productionRailway = 'https://iris-api.up.railway.app';
```

### Railway Considerations

- **Generous free tier:** $5/month credit
- **Better for development:** Good logging and debugging
- **Manual restart:** May need restart if model loads slowly
- **Volume support:** Can mount persistent storage for models

---

## Deployment on AWS EC2

### Step 1: Create EC2 Instance

1. **Go to** AWS EC2 Dashboard
2. **Click** "Launch Instance"
3. **Choose AMI:** Ubuntu 22.04 LTS (free tier eligible)
4. **Instance Type:** `t2.micro` or `t3.micro` (free tier)
5. **Storage:** 30GB SSD
6. **Security Group:** Allow:
   - Port 22 (SSH)
   - Port 80 (HTTP)
   - Port 443 (HTTPS)
   - Port 8000 (API - restrict to needed IPs)

### Step 2: Connect to Instance

```bash
# Download .pem key and set permissions
chmod 400 iris-key.pem

# SSH into instance
ssh -i iris-key.pem ubuntu@your-instance-public-ip
```

### Step 3: Set Up Environment

```bash
# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Logout and login for docker group to take effect
exit
# SSH back in
```

### Step 4: Clone Repository

```bash
cd ~
git clone https://github.com/yourusername/IRIS.git
cd IRIS
```

### Step 5: Configure Environment

```bash
cd backend
cp .env.example .env

# Edit .env with production values
nano .env
```

Set:
```
ENVIRONMENT=production
API_HOST=0.0.0.0
API_PORT=8000
API_WORKERS=4
CORS_ORIGINS=https://your-app.com
MODEL_PATH=ml/models/best_model_epoch4.pth
```

### Step 6: Deploy with Docker

```bash
cd ~/IRIS
docker-compose up -d

# Check logs
docker-compose logs -f iris-api

# Verify health
curl http://localhost:8000/health
```

### Step 7: Set Up Nginx Reverse Proxy (Recommended)

```bash
# Install Nginx
sudo apt-get install -y nginx

# Create Nginx config
sudo tee /etc/nginx/sites-available/iris > /dev/null << EOF
server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
        
        # Increase timeout for long-running predictions
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

# Enable site
sudo ln -s /etc/nginx/sites-available/iris /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### Step 8: Set Up SSL Certificate (Let's Encrypt)

```bash
# Install Certbot
sudo apt-get install -y certbot python3-certbot-nginx

# Get certificate
sudo certbot --nginx -d your-domain.com

# Test auto-renewal
sudo certbot renew --dry-run
```

### Step 9: Update Flutter

```dart
static const String productionAWS = 'https://your-domain.com';
```

### AWS Considerations

- **Free tier:** 750 hours/month of t2.micro/t3.micro
- **Data transfer:** 100GB/month outbound (to internet)
- **Storage:** 30GB EBS (free tier)
- **Best for:** Production with custom domain and SSL
- **Monitoring:** Enable CloudWatch for monitoring
- **Auto-scaling:** Can set up auto-scaling groups for production

---

## Flutter Configuration

### Update API Endpoints

In `lib/services/api_config.dart`:

```dart
// Change based on your deployment
static const String productionRender = 'https://your-render-url.onrender.com';
static const String productionRailway = 'https://your-railway-url.railway.app';
static const String productionAWS = 'https://your-domain.com';
```

### Build for Production

```bash
# Android
flutter build apk --release
flutter build appbundle --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

### Update Prediction Service Usage

In `analysis_screen.dart`:

```dart
// Development
PredictionService.predict(widget.imagePath)

// Production
PredictionService.predict(
  widget.imagePath,
  isProduction: true,
)

// Custom endpoint (for testing)
PredictionService.predict(
  widget.imagePath,
  customUrl: 'https://api.example.com',
)
```

---

## Monitoring & Logging

### Backend Logs

**Render/Railway:** View in dashboard logs panel

**AWS EC2:**
```bash
# Follow logs in real-time
docker-compose logs -f iris-api

# View specific container
docker logs container-name -f
```

### Health Endpoint

Periodically check:
```bash
curl https://your-api-url/health
```

Expected response:
```json
{
  "status": "healthy",
  "environment": "production",
  "model_loaded": true,
  "device": "cuda" or "cpu"
}
```

### Performance Monitoring

Monitor these metrics:
- **API response time:** Should be 3-5 seconds for predictions
- **Error rate:** Should be <1%
- **Uptime:** Target 99.5%+
- **Model load time:** Should be <30 seconds on startup

### Error Logging

All errors are logged with:
- Timestamp
- Log level (ERROR, WARNING, INFO)
- Module and function name
- Full exception stack trace
- Request details

---

## Firestore Security Rules

Deploy these rules to your Firestore for production:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Scans collection
    match /scans/{document=**} {
      // Only owner can read
      allow read: if request.auth.uid == resource.data.userId;
      
      // Only authenticated users can create
      allow create: if request.auth.uid != null && 
                       request.auth.uid == request.resource.data.userId &&
                       request.resource.data.keys().hasAll(['userId', 'predictedClass', 'confidenceScore', 'riskStatus', 'timestamp']);
      
      // Only owner can update/delete
      allow update, delete: if request.auth.uid == resource.data.userId;
    }
  }
}
```

---

## Troubleshooting

### Model Not Loading

**Error:** "Model file not found"

**Solution:**
1. Verify model file path in `.env`
2. Ensure model file is in deployment (not in .gitignore)
3. Check file permissions: `chmod 644 model.pth`

### High Memory Usage

**Problem:** Instance running out of memory

**Solutions:**
- Use `t3.medium` or larger for AWS
- Upgrade Railway/Render tier
- Enable GPU acceleration if available
- Reduce batch processing size

### Slow Predictions

**Problem:** Predictions taking >10 seconds

**Solutions:**
- Check device: `curl https://your-api/info` (should use GPU)
- Reduce image size in preprocessing
- Enable caching if same image processed multiple times
- Scale horizontally (multiple instances)

### CORS Errors

**Error:** "Cross-Origin Request Blocked"

**Solution:**
1. Update CORS_ORIGINS in `.env`:
   ```
   CORS_ORIGINS=https://your-app.com,https://cdn.your-app.com
   ```
2. Restart application
3. Clear browser cache

### Authentication Failures

**Error:** "Invalid or missing authentication token"

**Solution:**
1. Verify Bearer token format: `Authorization: Bearer <token>`
2. Check token validity in Firebase
3. Ensure AUTH_ENABLED=true in environment

### Database Connection Issues

**Error:** "Firestore connection failed"

**Solutions:**
1. Verify Firebase credentials in Flutter
2. Check Firestore security rules
3. Ensure internet connectivity from instance
4. Check firewall rules if behind corporate network

---

## Production Maintenance

### Regular Tasks

**Daily:**
- Monitor error logs for anomalies
- Check health endpoint responds correctly

**Weekly:**
- Review prediction accuracy metrics
- Check database growth rate
- Monitor cost/billing

**Monthly:**
- Update dependencies: `pip install --upgrade -r requirements.txt`
- Review and optimize security rules
- Backup critical data
- Test disaster recovery procedures

### Deployment Updates

To update production code:

```bash
# For all providers
git pull origin main
docker-compose up -d --build

# For Render/Railway: Auto-deploys on push to main
```

### Scaling

**When to scale up:**
- Response time >5 seconds consistently
- Error rate >1%
- CPU/Memory utilization >80%

**How to scale:**
- **Render:** Upgrade instance tier
- **Railway:** Increase resource allocation
- **AWS:** Launch additional instances, use load balancer

---

## Cost Estimation

### Render (Pay-as-you-go)
- Starter instance: $7/month
- Typical usage: $20-50/month

### Railway
- $5/month free credit included
- Typical usage: $10-30/month

### AWS (Free tier first year)
- t2.micro: Free (750 hours/month)
- Data transfer: 100GB/month free
- EBS storage: 30GB free
- Typical usage after free tier: $10-20/month

### Firebase (Generous free tier)
- Firestore: 1GB storage free
- Document operations: 50K reads, 20K writes, 20K deletes free daily
- Typical usage: Free tier sufficient for MVP

---

## Support & Resources

- **FastAPI Docs:** https://fastapi.tiangolo.com
- **Flutter Firebase:** https://firebase.flutter.dev
- **Render Docs:** https://render.com/docs
- **Railway Docs:** https://railway.app/docs
- **AWS EC2:** https://aws.amazon.com/ec2

---

**Ready to deploy? Start with Render (easiest) or Railway (best for development).**
