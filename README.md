# AI-Based Upper-Face Recognition Attendance System

A production-ready attendance system with mask-compatible face recognition using upper-face (eyes + nose bridge) detection.

## 🎯 Features

- **Upper-Face Recognition**: Works even with masks by focusing on eyes and nose bridge
- **Modular Architecture**: Clean, scalable design with separate components
- **Flexible Video Input**: Switch between mobile camera (testing) and RTSP CCTV streams
- **Real-time Processing**: Continuous attendance monitoring with configurable intervals
- **Flutter Admin App**: Modern mobile interface for system management
- **REST API**: Complete backend with FastAPI
- **Docker Support**: Containerized deployment ready
- **Security**: JWT authentication, role-based access, encrypted embeddings

## 🏗 System Architecture

```
VIDEO INPUT LAYER
→ FACE DETECTION LAYER
→ UPPER-FACE EXTRACTION LAYER
→ EMBEDDING GENERATION LAYER
→ MATCHING ENGINE
→ ATTENDANCE LOGIC
→ REST API
→ FLUTTER ADMIN APP
```

## 📁 Project Structure

```
├── backend/                    # Python FastAPI backend
│   ├── app/
│   │   ├── api/               # REST API endpoints
│   │   ├── models/            # SQLAlchemy database models
│   │   ├── services/          # Business logic services
│   │   ├── core/              # Core utilities (config, security)
│   │   ├── video/             # Video input handling
│   │   ├── recognition/       # Face recognition pipeline
│   │   └── database/          # Database configuration
│   ├── main.py                # FastAPI application entry point
│   ├── config.yaml            # Configuration file
│   ├── requirements.txt       # Python dependencies
│   └── Dockerfile             # Docker configuration
├── flutter_app/               # Flutter admin app
│   ├── lib/
│   │   ├── core/              # Core services and utilities
│   │   ├── features/          # Feature modules
│   │   └── widgets/           # Reusable UI components
│   └── pubspec.yaml           # Flutter dependencies
├── docker-compose.yml         # Multi-container deployment
└── README.md                  # This file
```

## 🚀 Quick Start

### Prerequisites

- Python 3.10+
- Flutter 3.10+
- PostgreSQL 15+
- Docker & Docker Compose (optional)

### Backend Setup

1. **Clone and Setup**
   ```bash
   git clone <repository-url>
   cd irish-detector/backend
   ```

2. **Install Dependencies**
   ```bash
   pip install -r requirements.txt
   ```

3. **Database Setup**
   ```bash
   # Create PostgreSQL database
   createdb attendance_db
   
   # Copy environment file
   cp .env.example .env
   
   # Edit .env with your database credentials
   ```

4. **Download Models**
   ```bash
   # Download ArcFace model (you'll need to get this from the official source)
   mkdir -p models
   # Place arcface.onnx in the models directory
   ```

5. **Run Backend**
   ```bash
   python main.py
   ```

### Flutter App Setup

1. **Navigate to Flutter App**
   ```bash
   cd flutter_app
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Run App**
   ```bash
   flutter run
   ```

### Docker Deployment

1. **Using Docker Compose**
   ```bash
   docker-compose up -d
   ```

2. **Initialize Database**
   ```bash
   docker-compose exec backend python -c "
   from app.database.database import engine, Base
   Base.metadata.create_all(bind=engine)
   "
   ```

## 📱 Mobile App Features

### Authentication
- Secure login with JWT tokens
- Remember me functionality
- Role-based access control

### Dashboard
- Real-time attendance statistics
- Quick action buttons
- Recent attendance overview

### Student Management
- Add/edit/delete students
- Upload multiple face images
- Face image processing and embedding generation

### Attendance
- View today's attendance
- Filter by date, student, department
- Manual attendance marking
- Export to CSV

### Reports
- Attendance analytics
- Export functionality
- Date range filtering

### Camera Management
- Add/configure cameras
- Test camera connections
- Switch between mobile and RTSP sources

## 🔧 Configuration

### Backend Configuration (config.yaml)

```yaml
# Video Source Configuration
video_source: mobile  # Options: mobile, rtsp

# Recognition Settings
recognition:
  similarity_threshold: 0.6
  frame_processing_interval: 1
  face_size: [112, 112]
  upper_face_ratio: 0.6

# Database Settings
database:
  url: "postgresql://username:password@localhost:5432/attendance_db"

# Security Settings
security:
  jwt_secret: "your-secret-key-here"
  jwt_algorithm: "HS256"
  jwt_expire_hours: 24
```

### Environment Variables (.env)

```bash
DATABASE_URL=postgresql://username:password@localhost:5432/attendance_db
JWT_SECRET_KEY=your-super-secret-jwt-key-here
ENVIRONMENT=development
```

## 🧠 Face Recognition Pipeline

1. **Face Detection**: Uses RetinaFace for accurate face detection
2. **Upper-Face Extraction**: Crops top 60% of face region (eyes + nose bridge)
3. **Normalization**: Resizes to 112x112 and normalizes pixel values
4. **Embedding Generation**: Uses ArcFace to generate 512D embeddings
5. **Matching**: Cosine similarity comparison with configurable threshold
6. **Attendance Logging**: Records attendance with confidence scores

## 🔐 Security Features

- **JWT Authentication**: Secure token-based authentication
- **Password Hashing**: bcrypt for secure password storage
- **Role-Based Access**: Admin and teacher roles
- **Encrypted Embeddings**: Face embeddings encrypted in database
- **API Security**: Request validation and error handling

## 📊 API Endpoints

### Authentication
- `POST /auth/login` - User login
- `GET /auth/me` - Get current user
- `POST /auth/logout` - User logout

### Students
- `GET /students` - List students
- `POST /students/register` - Register student with images
- `PUT /students/{id}` - Update student
- `DELETE /students/{id}` - Delete student

### Attendance
- `GET /attendance/today` - Today's attendance
- `GET /attendance` - Filtered attendance records
- `POST /attendance/manual` - Manual attendance marking
- `GET /attendance/export/csv` - Export attendance

### Cameras
- `GET /cameras` - List cameras
- `POST /cameras` - Add camera
- `PUT /cameras/{id}` - Update camera
- `POST /cameras/{id}/test-connection` - Test connection

## 🧪 Testing

### Backend Tests
```bash
cd backend
pytest tests/
```

### Flutter Tests
```bash
cd flutter_app
flutter test
```

## 📈 Performance Optimization

- **Frame Rate Limiting**: Configurable FPS to reduce CPU usage
- **Embedding Caching**: In-memory caching for fast recognition
- **Multithreading**: Parallel processing of detection and recognition
- **Image Resizing**: Optimized frame dimensions (640x480)

## 🚀 Future Extensions

- Multi-camera support
- GPU acceleration
- Cloud deployment
- Parent SMS alerts
- Student mobile portal
- Advanced analytics dashboard

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For support and questions:
- Create an issue on GitHub
- Check the documentation
- Review the API endpoints

## 🙏 Acknowledgments

- RetinaFace for face detection
- ArcFace for face embeddings
- FastAPI for backend framework
- Flutter for mobile app
- PostgreSQL for database
