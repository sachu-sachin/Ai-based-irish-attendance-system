# 🧠 MASTER PROMPT

You are a senior AI systems architect and full-stack engineer.

Your task is to build a production-ready Upper-Face (Eyes + Nose Bridge) Recognition Attendance System with the following requirements.

The system must be modular, scalable, and easily switchable between mobile camera input (for testing) and CCTV RTSP stream (for deployment).

## 🎯 PROJECT TITLE

**AI-Based Upper-Face Recognition Attendance System (Mask-Compatible)**

## 🏗 SYSTEM ARCHITECTURE

Build a clean modular architecture:

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

## 🧠 BACKEND REQUIREMENTS (PYTHON)

Use:
- Python 3.10+
- FastAPI
- PostgreSQL
- OpenCV
- RetinaFace (for detection)
- ArcFace (for embeddings)
- NumPy
- SQLAlchemy
- Uvicorn
- Docker-ready structure

## 🎥 VIDEO INPUT MODULE (IMPORTANT – MUST BE FLEXIBLE)

Create an abstract video source interface:

**Class:** `VideoSource`

**Implement:**
- `MobileCameraSource` (for testing)
  - Uses OpenCV VideoCapture(0)
- `RTSPCameraSource` (for CCTV future use)
  - Accepts RTSP URL
  - Handles reconnection
  - Adjustable FPS

System must allow switching source via config file.

**Example:**
```yaml
# config.yaml
video_source: mobile
# or
video_source: rtsp
```

## 👁 FACE & UPPER-FACE PROCESSING

1. Detect full face using RetinaFace
2. Extract bounding box
3. Crop top 60% of face region
4. Normalize image to 112x112
5. Generate embedding using ArcFace
6. Store embedding as float vector (512D)

## 🧑‍🎓 STUDENT REGISTRATION MODULE

**API:** `POST /register`

**Accept:**
- student_id
- name
- department
- year
- image (multiple allowed)

**Process:**
1. Extract upper-face embedding
2. Store in PostgreSQL
3. Encrypt embedding before storing

**Allow:**
- 5–10 images per student
- Average embeddings for stability

## 🧠 RECOGNITION PIPELINE

**Loop:**
1. Capture frame
2. Detect face
3. Extract upper-face
4. Generate embedding
5. Compare against cached embeddings
6. Use cosine similarity
7. Threshold configurable (default 0.6)

**If matched:**
- Check if already marked in last 30 mins
- If not → mark attendance

## 📊 DATABASE STRUCTURE

**Tables:**

### students
- id
- student_id
- name
- department
- year
- embedding (ARRAY FLOAT)
- created_at

### attendance
- id
- student_id
- timestamp
- camera_id
- confidence

### admins
- id
- username
- password_hash
- role

### cameras
- id
- name
- type (mobile/rtsp)
- location

Use SQLAlchemy models.

## 🔐 SECURITY

- Use bcrypt for password hashing
- JWT authentication
- Role-based access (admin/teacher)
- Encrypt embeddings before DB storage
- Use .env for secrets

## 📱 FLUTTER ADMIN APP REQUIREMENTS

**Architecture:**
- Clean architecture
- Provider or Riverpod for state management
- REST API integration
- Secure token storage

**Screens:**
- **Login Screen**
- **Dashboard**
  - Today attendance count
  - Unknown faces
- **Student Management**
  - Add student
  - Edit student
  - Upload face images
- **Attendance View**
  - Filter by date/class
  - Manual edit
- **Reports**
  - Export CSV
- **Camera Management**

## 🔄 FLEXIBILITY REQUIREMENT

The system must:
- Allow switching video source via config
- Support multiple cameras in future
- Allow adding new recognition model later
- Use dependency injection pattern

## 🧠 PERFORMANCE OPTIMIZATION

- Process 1 frame per second
- Cache embeddings in RAM
- Resize frames to 640x480
- Multithread detection and recognition
- Log inference time

## 📦 PROJECT STRUCTURE (REQUIRED)

```
backend/
├── app/
│   ├── api/
│   ├── models/
│   ├── services/
│   ├── core/
│   ├── video/
│   ├── recognition/
│   └── database/
├── main.py
├── config.yaml
├── requirements.txt
└── Dockerfile

flutter_app/
└── lib/
    ├── core/
    ├── features/
    ├── services/
    ├── screens/
    └── widgets/
```

## 🧪 TESTING

Include:
- Unit tests for recognition module
- API test cases
- Logging system
- Error handling
- Reconnection handling for RTSP

## 🚀 FUTURE EXTENSIONS

- Multi-camera support
- GPU acceleration
- Cloud deployment
- Parent SMS alerts
- Student mobile portal

## 📋 DELIVERABLES REQUIRED

- Complete backend code
- Complete Flutter app code
- Setup instructions
- Database migration script
- API documentation (Swagger)
- Docker deployment guide
- README.md

**Write production-level clean code.**
**Avoid dummy placeholders.**

---

🧠 MASTER PROMPT END
