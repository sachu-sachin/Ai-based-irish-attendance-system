# 🚀 Quick Start Guide

## Prerequisites

- **Python 3.10+**
- **PostgreSQL 15+**
- **Flutter 3.10+** (for mobile app)
- **Git**

## 📋 Step-by-Step Setup

### 1. Database Setup

```bash
# Install PostgreSQL (Ubuntu/Debian)
sudo apt update
sudo apt install postgresql postgresql-contrib

# Create database
sudo -u postgres createdb attendance_db

# Create user (optional)
sudo -u postgres psql
CREATE USER attendance_user WITH PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE attendance_db TO attendance_user;
\q
```

### 2. Backend Setup

```bash
# Navigate to backend directory
cd backend

# Run setup script
python setup.py

# Or manual setup:
pip install -r requirements.txt
cp .env.example .env
# Edit .env with your database credentials
```

### 3. Download Face Recognition Model

```bash
# Create models directory
mkdir -p models

# Download ArcFace model (you need to get this from official source)
# Place arcface.onnx in models/ directory
```

### 4. Start Backend Server

```bash
# Start the server
python main.py

# Or with uvicorn directly
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### 5. Test Backend API

```bash
# Run API tests
python test_api.py

# Or manually test with curl
curl http://localhost:8000/health
```

### 6. Flutter App Setup

```bash
# Navigate to flutter app directory
cd flutter_app

# Install dependencies
flutter pub get

# Run the app
flutter run

# Or build for specific platform
flutter build apk    # Android
flutter build ios    # iOS
```

## 🔧 Configuration

### Backend Configuration (config.yaml)

```yaml
# Video source: mobile or rtsp
video_source: mobile

# Database settings
database:
  url: "postgresql://username:password@localhost:5432/attendance_db"

# Security
security:
  jwt_secret: "your-secret-key-here"
  jwt_expire_hours: 24

# Recognition settings
recognition:
  similarity_threshold: 0.6
  frame_processing_interval: 1
```

### Environment Variables (.env)

```bash
DATABASE_URL=postgresql://username:password@localhost:5432/attendance_db
JWT_SECRET_KEY=your-super-secret-jwt-key-here
ENVIRONMENT=development
```

## 🧪 Testing

### Backend Tests

```bash
# Run API tests
python test_api.py

# Run unit tests (if available)
pytest tests/
```

### Flutter Tests

```bash
cd flutter_app
flutter test
```

## 🐳 Docker Deployment

```bash
# Build and start all services
docker-compose up -d

# Initialize database
docker-compose exec backend python setup.py

# Check logs
docker-compose logs -f backend
```

## 📱 Mobile App Testing

1. **Install Flutter SDK**
2. **Set up Android/iOS development environment**
3. **Run the app**: `flutter run`
4. **Test with backend**: Ensure backend is running on same network

## 🔍 API Documentation

Once backend is running, visit:
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

## 👤 Default Login

- **Username**: `admin`
- **Password**: `admin123`

## 🚨 Troubleshooting

### Common Issues

1. **Database Connection Failed**
   - Check PostgreSQL is running
   - Verify database URL in .env
   - Ensure database exists

2. **Face Recognition Model Not Found**
   - Download ArcFace model to models/arcface.onnx
   - Check model file permissions

3. **Camera Not Working**
   - For mobile: Check camera permissions
   - For RTSP: Verify RTSP URL and network connectivity

4. **Flutter App Not Connecting**
   - Check backend URL in app
   - Ensure both devices are on same network
   - Verify firewall settings

### Debug Mode

```bash
# Backend debug mode
python main.py

# Flutter debug mode
flutter run --debug
```

## 📊 Monitoring

### Health Checks

```bash
# Backend health
curl http://localhost:8000/health

# Service status
curl -H "Authorization: Bearer <token>" http://localhost:8000/service/status
```

### Logs

```bash
# Backend logs
tail -f logs/app.log

# Docker logs
docker-compose logs -f backend
```

## 🎯 Next Steps

1. **Configure camera settings** for your environment
2. **Add students** with face images
3. **Test attendance recognition** with live camera
4. **Deploy to production** using Docker
5. **Set up monitoring** and alerts

## 📞 Support

For issues:
1. Check the troubleshooting section
2. Review logs for error messages
3. Test API endpoints manually
4. Verify configuration files

---

**🎉 Your AI-Based Upper-Face Recognition Attendance System is ready!**
