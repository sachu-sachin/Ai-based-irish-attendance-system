import logging
import os
import shutil
from contextlib import asynccontextmanager
from datetime import date, datetime, timedelta
from typing import Any, Dict, List, Optional

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, File, Form, HTTPException, UploadFile, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from pydantic import BaseModel
from sqlalchemy import (
    Boolean,
    Column,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    create_engine,
    text,
)
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import Session, relationship, sessionmaker

load_dotenv()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Patch for bcrypt >= 4.x incompatibility with passlib
try:
    import bcrypt as _bcrypt_mod
    if not hasattr(_bcrypt_mod, '__about__'):
        import types
        _bcrypt_mod.__about__ = types.SimpleNamespace(__version__=_bcrypt_mod.__version__)
except Exception:
    pass

# Lazy-import the ML engine so the server still starts if ML deps are missing
try:
    from ml.iris_engine import IrisEngine
    from ml.iris_matcher import EnrolledIris
    _iris_engine = IrisEngine()
    ML_AVAILABLE = True
except Exception as _ml_err:
    _iris_engine = None
    ML_AVAILABLE = False
    logger.warning(f"ML iris engine not available: {_ml_err}")

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./attendance.db")
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False}, echo=False)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

SECRET_KEY = os.getenv("JWT_SECRET_KEY", "your-secret-key-change-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 480
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
security = HTTPBearer(auto_error=False)

UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

# ─────────────────────────────────────────────
# SQLAlchemy Models
# ─────────────────────────────────────────────

class AdminUser(Base):
    __tablename__ = "admin_users"
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    hashed_password = Column(String)
    role = Column(String, default="admin")
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    last_login = Column(DateTime, nullable=True)


class Department(Base):
    __tablename__ = "departments"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True)
    students = relationship("Student", back_populates="department")
    classrooms = relationship("Classroom", back_populates="department")


class Subject(Base):
    __tablename__ = "subjects"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True)
    subject_type = Column(String, default="General")  # Quantum, Logical, Softskills, General


class Classroom(Base):
    __tablename__ = "classrooms"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    department_id = Column(Integer, ForeignKey("departments.id"), nullable=True)
    department = relationship("Department", back_populates="classrooms")


class Staff(Base):
    __tablename__ = "staff"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    subject_id = Column(Integer, ForeignKey("subjects.id"), nullable=True)
    subject = relationship("Subject")
    username = Column(String, unique=True, index=True)
    hashed_password = Column(String)
    role = Column(String, default="staff")
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    attendance_records = relationship("AttendanceRecord", back_populates="staff")
    timetable_entries = relationship("TimetableEntry", back_populates="staff")


class Student(Base):
    __tablename__ = "students"
    id = Column(Integer, primary_key=True, index=True)
    roll_number = Column(String, unique=True, index=True)
    name = Column(String, index=True)
    year = Column(String)  # 1st, 2nd, 3rd, 4th
    department_id = Column(Integer, ForeignKey("departments.id"), nullable=True)
    department = relationship("Department", back_populates="students")
    cgpa = Column(Float, nullable=True)
    student_type = Column(String, nullable=True)  # Product, Service
    classroom_id = Column(Integer, ForeignKey("classrooms.id"), nullable=True)
    classroom = relationship("Classroom")
    subjects = Column(Text, nullable=True)  # comma-separated subject IDs
    faculty_id = Column(Integer, ForeignKey("staff.id"), nullable=True)
    faculty_slot = Column(String, nullable=True)  # 1st, End
    iris_left_path = Column(String, nullable=True)
    iris_right_path = Column(String, nullable=True)
    iris_feature_left  = Column(Text, nullable=True)   # hex IrisCode (2048-bit)
    iris_feature_right = Column(Text, nullable=True)   # hex IrisCode (2048-bit)
    is_enrolled = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    attendance_records = relationship("AttendanceRecord", back_populates="student")


class TimetableEntry(Base):
    __tablename__ = "timetable_entries"
    id = Column(Integer, primary_key=True, index=True)
    day_of_week = Column(String)  # Monday, Tuesday, ...
    time_slot = Column(String)  # e.g. "9:00 AM - 10:00 AM"
    staff_id = Column(Integer, ForeignKey("staff.id"), nullable=True)
    staff = relationship("Staff", back_populates="timetable_entries")
    subject_id = Column(Integer, ForeignKey("subjects.id"), nullable=True)
    subject = relationship("Subject")
    classroom_id = Column(Integer, ForeignKey("classrooms.id"), nullable=True)
    classroom = relationship("Classroom")
    created_at = Column(DateTime, default=datetime.utcnow)


class AttendanceRecord(Base):
    __tablename__ = "attendance_records"
    id = Column(Integer, primary_key=True, index=True)
    student_id = Column(Integer, ForeignKey("students.id"))
    student = relationship("Student", back_populates="attendance_records")
    staff_id = Column(Integer, ForeignKey("staff.id"), nullable=True)
    staff = relationship("Staff", back_populates="attendance_records")
    subject_id = Column(Integer, ForeignKey("subjects.id"), nullable=True)
    subject = relationship("Subject")
    date = Column(Date, default=date.today)
    status = Column(String, default="present")  # present, absent, fake_eye
    is_fake_eye = Column(Boolean, default=False)
    confidence = Column(Float, default=1.0)
    timestamp = Column(DateTime, default=datetime.utcnow)


# ─────────────────────────────────────────────
# Pydantic Schemas
# ─────────────────────────────────────────────

class LoginRequest(BaseModel):
    username: str
    password: str


class Token(BaseModel):
    access_token: str
    token_type: str
    user: Dict[str, Any]


class DepartmentCreate(BaseModel):
    name: str


class DepartmentOut(BaseModel):
    id: int
    name: str
    class Config:
        from_attributes = True


class SubjectCreate(BaseModel):
    name: str
    subject_type: str = "General"


class SubjectOut(BaseModel):
    id: int
    name: str
    subject_type: str
    class Config:
        from_attributes = True


class ClassroomCreate(BaseModel):
    name: str
    department_id: Optional[int] = None


class ClassroomOut(BaseModel):
    id: int
    name: str
    department_id: Optional[int] = None
    class Config:
        from_attributes = True


class StaffCreate(BaseModel):
    name: str
    subject_id: Optional[int] = None
    password: Optional[str] = None


class StaffOut(BaseModel):
    id: int
    name: str
    subject_id: Optional[int] = None
    subject_name: Optional[str] = None
    username: str
    role: str
    is_active: bool
    created_at: datetime
    class Config:
        from_attributes = True


class StudentOut(BaseModel):
    id: int
    roll_number: str
    name: str
    year: str
    department_id: Optional[int] = None
    department_name: Optional[str] = None
    cgpa: Optional[float] = None
    student_type: Optional[str] = None
    classroom_id: Optional[int] = None
    classroom_name: Optional[str] = None
    subjects: Optional[str] = None
    faculty_id: Optional[int] = None
    faculty_name: Optional[str] = None
    faculty_slot: Optional[str] = None
    is_enrolled: bool
    created_at: datetime
    class Config:
        from_attributes = True


class TimetableCreate(BaseModel):
    day_of_week: str
    time_slot: str
    staff_id: Optional[int] = None
    subject_id: Optional[int] = None
    classroom_id: Optional[int] = None


class TimetableOut(BaseModel):
    id: int
    day_of_week: str
    time_slot: str
    staff_id: Optional[int] = None
    staff_name: Optional[str] = None
    subject_id: Optional[int] = None
    subject_name: Optional[str] = None
    classroom_id: Optional[int] = None
    classroom_name: Optional[str] = None
    class Config:
        from_attributes = True


class AttendanceOut(BaseModel):
    id: int
    student_id: int
    student_name: str
    roll_number: str
    staff_id: Optional[int] = None
    subject_id: Optional[int] = None
    subject_name: Optional[str] = None
    date: str
    status: str
    is_fake_eye: bool
    confidence: float
    timestamp: str
    class Config:
        from_attributes = True


class ManualAttendanceRequest(BaseModel):
    student_id: int
    subject_id: Optional[int] = None
    staff_id: Optional[int] = None
    status: str = "present"
    confidence: float = 1.0


class IrisAttendanceRequest(BaseModel):
    student_id: int
    subject_id: Optional[int] = None
    staff_id: Optional[int] = None
    is_fake_eye: bool = False
    confidence: float = 1.0


class DashboardStats(BaseModel):
    total_students: int
    total_staff: int
    today_attendance: int
    total_subjects: int
    total_departments: int


class PasswordChangeRequest(BaseModel):
    current_password: str
    new_password: str


# ─────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


import bcrypt

def verify_password(plain: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(plain.encode('utf-8'), hashed.encode('utf-8'))
    except Exception:
        return False


def get_password_hash(password: str) -> str:
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=15))
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: Session = Depends(get_db),
):
    if credentials is None:
        raise HTTPException(status_code=401, detail="Not authenticated")
    try:
        payload = jwt.decode(credentials.credentials, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        role: str = payload.get("role", "admin")
        if username is None:
            raise HTTPException(status_code=401, detail="Invalid credentials")
        return {"username": username, "role": role}
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid credentials")


def slugify_name(name: str) -> str:
    return name.strip().lower().replace(" ", "_")


def seed_defaults(db: Session):
    """Seed departments, subjects, classrooms, and admin user if missing."""
    # Admin user — truncate password to 72 bytes to satisfy bcrypt limit
    if not db.query(AdminUser).filter(AdminUser.username == "admin").first():
        raw_password = "admin123"[:72]
        admin = AdminUser(
            username="admin",
            hashed_password=get_password_hash(raw_password),
            role="admin",
        )
        db.add(admin)
        try:
            db.commit()
        except Exception:
            db.rollback()

    # Departments
    default_departments = ["Computer Science", "Electronics", "Mechanical", "Civil", "Information Technology"]
    for dname in default_departments:
        if not db.query(Department).filter(Department.name == dname).first():
            try:
                db.add(Department(name=dname))
                db.commit()
            except Exception:
                db.rollback()

    # Subjects
    default_subjects = [
        ("Quantum Computing", "Quantum"),
        ("Logical Reasoning", "Logical"),
        ("Soft Skills", "Softskills"),
        ("Data Structures", "General"),
        ("Operating Systems", "General"),
        ("Database Systems", "General"),
    ]
    for sname, stype in default_subjects:
        if not db.query(Subject).filter(Subject.name == sname).first():
            try:
                db.add(Subject(name=sname, subject_type=stype))
                db.commit()
            except Exception:
                db.rollback()

    # Classrooms
    default_rooms = ["A101", "A102", "B101", "B102", "C101", "Lab-1", "Lab-2"]
    for rname in default_rooms:
        if not db.query(Classroom).filter(Classroom.name == rname).first():
            try:
                db.add(Classroom(name=rname))
                db.commit()
            except Exception:
                db.rollback()


# ─────────────────────────────────────────────
# App Lifecycle
# ─────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting Iris Attendance System…")
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        seed_defaults(db)
        logger.info("Database initialized and seeded.")
        print("\n" + "="*60, flush=True)
        print("      🚀 IRIS ATTENDANCE SYSTEM - SERVER STARTED 🚀", flush=True)
        print(f"      SESSION ID: {datetime.utcnow().strftime('%H%M%S')}", flush=True)
        print("      LISTENING ON PORT 8001", flush=True)
        print("="*60 + "\n", flush=True)
    except Exception as e:
        logger.error(f"Seed error: {e}")
    finally:
        db.close()
    yield
    logger.info("Shutting down.")


app = FastAPI(
    title="Iris-Based Attendance System",
    description="Student & Staff attendance managed via iris recognition",
    version="2.0.0",
    lifespan=lifespan,
)

@app.on_event("startup")
async def startup_event():
    logger.info("Iris Attendance System is ready.")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ─────────────────────────────────────────────
# Auth Routes
# ─────────────────────────────────────────────

@app.get("/")
async def root():
    return {"message": "Iris Attendance System", "status": "running", "version": "2.0.0"}


@app.get("/health")
async def health_check():
    try:
        db = SessionLocal()
        db.execute(text("SELECT 1"))
        db.close()
        db_status = "connected"
    except Exception as e:
        db_status = f"error: {str(e)}"
    return {"status": "healthy", "database": db_status, "timestamp": datetime.utcnow().isoformat()}


@app.post("/auth/login")
async def login(login_data: LoginRequest, db: Session = Depends(get_db)):
    username = login_data.username.strip().lower()
    password = login_data.password.strip()
    
    # Check admin users
    admin = db.query(AdminUser).filter(AdminUser.username == username).first()
    if admin and verify_password(password, admin.hashed_password):
            admin.last_login = datetime.utcnow()
            db.commit()
            token_data = {"sub": admin.username, "role": admin.role, "id": admin.id}
            access_token = create_access_token(token_data, timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
            return {
                "access_token": access_token,
                "token_type": "bearer",
                "user": {"id": admin.id, "username": admin.username, "role": admin.role},
            }
    else:
        print(f"Admin user '{username}' NOT found in admin_users table.")

    # Check staff users
    staff = db.query(Staff).filter(Staff.username == username).first()
    if staff and verify_password(password, staff.hashed_password):
        token_data = {"sub": staff.username, "role": "staff", "id": staff.id}
        access_token = create_access_token(token_data, timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
        return {
            "access_token": access_token,
            "token_type": "bearer",
            "user": {"id": staff.id, "username": staff.username, "role": "staff", "name": staff.name},
        }

    raise HTTPException(status_code=401, detail="Incorrect username or password")


@app.get("/auth/me")
async def get_me(current_user: dict = Depends(get_current_user)):
    return current_user


@app.post("/auth/logout")
async def logout(current_user: dict = Depends(get_current_user)):
    return {"message": "Logged out successfully"}


@app.post("/auth/change-password")
async def change_password(
    req: PasswordChangeRequest,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    admin = db.query(AdminUser).filter(AdminUser.username == current_user["username"]).first()
    if not admin or not verify_password(req.current_password, admin.hashed_password):
        raise HTTPException(status_code=400, detail="Current password is incorrect")
    admin.hashed_password = get_password_hash(req.new_password)
    db.commit()
    return {"message": "Password changed successfully"}


# ─────────────────────────────────────────────
# Department Routes
# ─────────────────────────────────────────────

@app.post("/departments/", response_model=DepartmentOut)
async def create_department(dept: DepartmentCreate, db: Session = Depends(get_db), _=Depends(get_current_user)):
    if db.query(Department).filter(Department.name == dept.name).first():
        raise HTTPException(status_code=400, detail="Department already exists")
    obj = Department(name=dept.name)
    db.add(obj)
    db.commit()
    db.refresh(obj)
    return obj


@app.get("/departments/", response_model=List[DepartmentOut])
async def list_departments(db: Session = Depends(get_db)):
    return db.query(Department).all()


@app.delete("/departments/{dept_id}")
async def delete_department(dept_id: int, db: Session = Depends(get_db), _=Depends(get_current_user)):
    obj = db.query(Department).filter(Department.id == dept_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Department not found")
    db.delete(obj)
    db.commit()
    return {"message": "Deleted"}


# ─────────────────────────────────────────────
# Subject Routes
# ─────────────────────────────────────────────

@app.post("/subjects/", response_model=SubjectOut)
async def create_subject(sub: SubjectCreate, db: Session = Depends(get_db), _=Depends(get_current_user)):
    if db.query(Subject).filter(Subject.name == sub.name).first():
        raise HTTPException(status_code=400, detail="Subject already exists")
    obj = Subject(name=sub.name, subject_type=sub.subject_type)
    db.add(obj)
    db.commit()
    db.refresh(obj)
    return obj


@app.get("/subjects/", response_model=List[SubjectOut])
async def list_subjects(db: Session = Depends(get_db)):
    return db.query(Subject).all()


@app.delete("/subjects/{subject_id}")
async def delete_subject(subject_id: int, db: Session = Depends(get_db), _=Depends(get_current_user)):
    obj = db.query(Subject).filter(Subject.id == subject_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Subject not found")
    db.delete(obj)
    db.commit()
    return {"message": "Deleted"}


# ─────────────────────────────────────────────
# Classroom Routes
# ─────────────────────────────────────────────

@app.post("/classrooms/", response_model=ClassroomOut)
async def create_classroom(room: ClassroomCreate, db: Session = Depends(get_db), _=Depends(get_current_user)):
    obj = Classroom(name=room.name, department_id=room.department_id)
    db.add(obj)
    db.commit()
    db.refresh(obj)
    return obj


@app.get("/classrooms/", response_model=List[ClassroomOut])
async def list_classrooms(db: Session = Depends(get_db)):
    return db.query(Classroom).all()


@app.delete("/classrooms/{room_id}")
async def delete_classroom(room_id: int, db: Session = Depends(get_db), _=Depends(get_current_user)):
    obj = db.query(Classroom).filter(Classroom.id == room_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Classroom not found")
    db.delete(obj)
    db.commit()
    return {"message": "Deleted"}


# ─────────────────────────────────────────────
# Staff Routes
# ─────────────────────────────────────────────

@app.post("/staff/", response_model=StaffOut)
async def register_staff(staff_data: StaffCreate, db: Session = Depends(get_db), _=Depends(get_current_user)):
    username = slugify_name(staff_data.name)
    # Ensure unique username
    base = username
    counter = 1
    while db.query(Staff).filter(Staff.username == username).first():
        username = f"{base}_{counter}"
        counter += 1

    password = staff_data.password or f"staff@{username[:4]}123"
    obj = Staff(
        name=staff_data.name,
        subject_id=staff_data.subject_id,
        username=username,
        hashed_password=get_password_hash(password),
    )
    db.add(obj)
    db.commit()
    db.refresh(obj)

    subject_name = None
    if obj.subject_id:
        sub = db.query(Subject).filter(Subject.id == obj.subject_id).first()
        subject_name = sub.name if sub else None

    return StaffOut(
        id=obj.id,
        name=obj.name,
        subject_id=obj.subject_id,
        subject_name=subject_name,
        username=obj.username,
        role=obj.role,
        is_active=obj.is_active,
        created_at=obj.created_at,
    )


@app.get("/staff/", response_model=List[StaffOut])
async def list_staff(db: Session = Depends(get_db), _=Depends(get_current_user)):
    staff_list = db.query(Staff).all()
    result = []
    for s in staff_list:
        subject_name = s.subject.name if s.subject else None
        result.append(StaffOut(
            id=s.id, name=s.name, subject_id=s.subject_id, subject_name=subject_name,
            username=s.username, role=s.role, is_active=s.is_active, created_at=s.created_at,
        ))
    return result


@app.get("/staff/{staff_id}", response_model=StaffOut)
async def get_staff(staff_id: int, db: Session = Depends(get_db), _=Depends(get_current_user)):
    s = db.query(Staff).filter(Staff.id == staff_id).first()
    if not s:
        raise HTTPException(status_code=404, detail="Staff not found")
    subject_name = s.subject.name if s.subject else None
    return StaffOut(
        id=s.id, name=s.name, subject_id=s.subject_id, subject_name=subject_name,
        username=s.username, role=s.role, is_active=s.is_active, created_at=s.created_at,
    )


@app.delete("/staff/{staff_id}")
async def delete_staff(staff_id: int, db: Session = Depends(get_db), _=Depends(get_current_user)):
    obj = db.query(Staff).filter(Staff.id == staff_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Staff not found")
    db.delete(obj)
    db.commit()
    return {"message": "Deleted"}


@app.get("/staff/{staff_id}/attendance")
async def get_staff_attendance(
    staff_id: int,
    attendance_date: Optional[str] = None,
    db: Session = Depends(get_db),
    _=Depends(get_current_user),
):
    query = db.query(AttendanceRecord).filter(AttendanceRecord.staff_id == staff_id)
    if attendance_date:
        try:
            d = datetime.strptime(attendance_date, "%Y-%m-%d").date()
            query = query.filter(AttendanceRecord.date == d)
        except ValueError:
            pass
    records = query.order_by(AttendanceRecord.timestamp.desc()).all()
    result = []
    for r in records:
        result.append({
            "id": r.id,
            "student_id": r.student_id,
            "student_name": r.student.name if r.student else "",
            "roll_number": r.student.roll_number if r.student else "",
            "subject_name": r.subject.name if r.subject else "",
            "date": r.date.isoformat(),
            "status": r.status,
            "is_fake_eye": r.is_fake_eye,
            "confidence": r.confidence,
            "timestamp": r.timestamp.isoformat(),
        })
    return result


# ─────────────────────────────────────────────
# Student Routes
# ─────────────────────────────────────────────

@app.post("/students/register")
async def register_student(
    roll_number: str = Form(...),
    name: str = Form(...),
    year: str = Form(...),
    department_id: Optional[int] = Form(None),
    cgpa: Optional[float] = Form(None),
    student_type: Optional[str] = Form(None),
    classroom_id: Optional[int] = Form(None),
    subjects: Optional[str] = Form(None),
    faculty_id: Optional[int] = Form(None),
    faculty_slot: Optional[str] = Form(None),
    iris_left: Optional[UploadFile] = File(None),
    iris_right: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db),
    _=Depends(get_current_user),
):
    if db.query(Student).filter(Student.roll_number == roll_number).first():
        raise HTTPException(status_code=400, detail="Roll number already registered")

    iris_left_path = None
    iris_right_path = None

    if iris_left:
        left_path = os.path.join(UPLOAD_DIR, f"{roll_number}_left_{iris_left.filename}")
        with open(left_path, "wb") as f:
            shutil.copyfileobj(iris_left.file, f)
        iris_left_path = left_path

    if iris_right:
        right_path = os.path.join(UPLOAD_DIR, f"{roll_number}_right_{iris_right.filename}")
        with open(right_path, "wb") as f:
            shutil.copyfileobj(iris_right.file, f)
        iris_right_path = right_path

    student = Student(
        roll_number=roll_number,
        name=name,
        year=year,
        department_id=department_id,
        cgpa=cgpa,
        student_type=student_type,
        classroom_id=classroom_id,
        subjects=subjects,
        faculty_id=faculty_id,
        faculty_slot=faculty_slot,
        iris_left_path=iris_left_path,
        iris_right_path=iris_right_path,
        is_enrolled=(iris_left_path is not None and iris_right_path is not None),
    )
    db.add(student)
    db.commit()
    db.refresh(student)

    # ── Extract iris features (ML enrollment) ──────────────────────────
    if ML_AVAILABLE and _iris_engine:
        if iris_left_path:
            try:
                with open(iris_left_path, "rb") as f_:
                    enroll_l = _iris_engine.enroll(f_.read())
                if enroll_l.success:
                    student.iris_feature_left = enroll_l.feature_left
                    student.iris_feature_right = enroll_l.feature_right
                    logger.info(f"Left iris enrolled for {roll_number}")
            except Exception as e:
                logger.warning(f"Left iris enrollment failed: {e}")
        if iris_right_path:
            try:
                with open(iris_right_path, "rb") as f_:
                    enroll_r = _iris_engine.enroll(f_.read())
                if enroll_r.success and enroll_r.feature_right:
                    student.iris_feature_right = enroll_r.feature_right
                    logger.info(f"Right iris enrolled for {roll_number}")
            except Exception as e:
                logger.warning(f"Right iris enrollment failed: {e}")
        db.commit()
        db.refresh(student)
    # ───────────────────────────────────────────────────────────────────

    dept_name = student.department.name if student.department else None
    room_name = student.classroom.name if student.classroom else None
    faculty_name = None
    if student.faculty_id:
        f = db.query(Staff).filter(Staff.id == student.faculty_id).first()
        faculty_name = f.name if f else None

    return StudentOut(
        id=student.id,
        roll_number=student.roll_number,
        name=student.name,
        year=student.year,
        department_id=student.department_id,
        department_name=dept_name,
        cgpa=student.cgpa,
        student_type=student.student_type,
        classroom_id=student.classroom_id,
        classroom_name=room_name,
        subjects=student.subjects,
        faculty_id=student.faculty_id,
        faculty_name=faculty_name,
        faculty_slot=student.faculty_slot,
        is_enrolled=student.is_enrolled,
        created_at=student.created_at,
    )


@app.get("/students/", response_model=List[StudentOut])
async def list_students(
    skip: int = 0,
    limit: int = 100,
    department_id: Optional[int] = None,
    year: Optional[str] = None,
    db: Session = Depends(get_db),
    _=Depends(get_current_user),
):
    query = db.query(Student)
    if department_id:
        query = query.filter(Student.department_id == department_id)
    if year:
        query = query.filter(Student.year == year)
    students = query.offset(skip).limit(limit).all()
    result = []
    for s in students:
        dept_name = s.department.name if s.department else None
        room_name = s.classroom.name if s.classroom else None
        faculty_name = None
        if s.faculty_id:
            f = db.query(Staff).filter(Staff.id == s.faculty_id).first()
            faculty_name = f.name if f else None
        result.append(StudentOut(
            id=s.id, roll_number=s.roll_number, name=s.name, year=s.year,
            department_id=s.department_id, department_name=dept_name,
            cgpa=s.cgpa, student_type=s.student_type,
            classroom_id=s.classroom_id, classroom_name=room_name,
            subjects=s.subjects, faculty_id=s.faculty_id, faculty_name=faculty_name,
            faculty_slot=s.faculty_slot, is_enrolled=s.is_enrolled, created_at=s.created_at,
        ))
    return result


@app.get("/students/{student_id}", response_model=StudentOut)
async def get_student(student_id: int, db: Session = Depends(get_db), _=Depends(get_current_user)):
    s = db.query(Student).filter(Student.id == student_id).first()
    if not s:
        raise HTTPException(status_code=404, detail="Student not found")
    dept_name = s.department.name if s.department else None
    room_name = s.classroom.name if s.classroom else None
    faculty_name = None
    if s.faculty_id:
        f = db.query(Staff).filter(Staff.id == s.faculty_id).first()
        faculty_name = f.name if f else None
    return StudentOut(
        id=s.id, roll_number=s.roll_number, name=s.name, year=s.year,
        department_id=s.department_id, department_name=dept_name,
        cgpa=s.cgpa, student_type=s.student_type,
        classroom_id=s.classroom_id, classroom_name=room_name,
        subjects=s.subjects, faculty_id=s.faculty_id, faculty_name=faculty_name,
        faculty_slot=s.faculty_slot, is_enrolled=s.is_enrolled, created_at=s.created_at,
    )


@app.put("/students/{student_id}")
async def update_student(
    student_id: int,
    name: Optional[str] = Form(None),
    year: Optional[str] = Form(None),
    department_id: Optional[int] = Form(None),
    cgpa: Optional[float] = Form(None),
    student_type: Optional[str] = Form(None),
    classroom_id: Optional[int] = Form(None),
    subjects: Optional[str] = Form(None),
    faculty_id: Optional[int] = Form(None),
    faculty_slot: Optional[str] = Form(None),
    iris_left: Optional[UploadFile] = File(None),
    iris_right: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db),
    _=Depends(get_current_user),
):
    s = db.query(Student).filter(Student.id == student_id).first()
    if not s:
        raise HTTPException(status_code=404, detail="Student not found")

    if name is not None: s.name = name
    if year is not None: s.year = year
    if department_id is not None: s.department_id = department_id
    if cgpa is not None: s.cgpa = cgpa
    if student_type is not None: s.student_type = student_type
    if classroom_id is not None: s.classroom_id = classroom_id
    if subjects is not None: s.subjects = subjects
    if faculty_id is not None: s.faculty_id = faculty_id
    if faculty_slot is not None: s.faculty_slot = faculty_slot

    if iris_left:
        left_path = os.path.join(UPLOAD_DIR, f"{s.roll_number}_left_{iris_left.filename}")
        with open(left_path, "wb") as f_:
            shutil.copyfileobj(iris_left.file, f_)
        s.iris_left_path = left_path

    if iris_right:
        right_path = os.path.join(UPLOAD_DIR, f"{s.roll_number}_right_{iris_right.filename}")
        with open(right_path, "wb") as f_:
            shutil.copyfileobj(iris_right.file, f_)
        s.iris_right_path = right_path

    s.is_enrolled = (s.iris_left_path is not None and s.iris_right_path is not None)
    db.commit()
    return {"message": "Student updated successfully"}


@app.delete("/students/{student_id}")
async def delete_student(student_id: int, db: Session = Depends(get_db), _=Depends(get_current_user)):
    s = db.query(Student).filter(Student.id == student_id).first()
    if not s:
        raise HTTPException(status_code=404, detail="Student not found")
    db.delete(s)
    db.commit()
    return {"message": "Deleted"}


# ─────────────────────────────────────────────
# Timetable Routes
# ─────────────────────────────────────────────

@app.post("/admin/timetable/", response_model=TimetableOut)
async def create_timetable_entry(entry: TimetableCreate, db: Session = Depends(get_db), _=Depends(get_current_user)):
    obj = TimetableEntry(
        day_of_week=entry.day_of_week,
        time_slot=entry.time_slot,
        staff_id=entry.staff_id,
        subject_id=entry.subject_id,
        classroom_id=entry.classroom_id,
    )
    db.add(obj)
    db.commit()
    db.refresh(obj)
    staff_name = obj.staff.name if obj.staff else None
    subject_name = obj.subject.name if obj.subject else None
    classroom_name = obj.classroom.name if obj.classroom else None
    return TimetableOut(
        id=obj.id, day_of_week=obj.day_of_week, time_slot=obj.time_slot,
        staff_id=obj.staff_id, staff_name=staff_name,
        subject_id=obj.subject_id, subject_name=subject_name,
        classroom_id=obj.classroom_id, classroom_name=classroom_name,
    )


@app.get("/admin/timetable/", response_model=List[TimetableOut])
async def list_timetable(db: Session = Depends(get_db), _=Depends(get_current_user)):
    entries = db.query(TimetableEntry).all()
    result = []
    for obj in entries:
        staff_name = obj.staff.name if obj.staff else None
        subject_name = obj.subject.name if obj.subject else None
        classroom_name = obj.classroom.name if obj.classroom else None
        result.append(TimetableOut(
            id=obj.id, day_of_week=obj.day_of_week, time_slot=obj.time_slot,
            staff_id=obj.staff_id, staff_name=staff_name,
            subject_id=obj.subject_id, subject_name=subject_name,
            classroom_id=obj.classroom_id, classroom_name=classroom_name,
        ))
    return result


@app.delete("/admin/timetable/{entry_id}")
async def delete_timetable_entry(entry_id: int, db: Session = Depends(get_db), _=Depends(get_current_user)):
    obj = db.query(TimetableEntry).filter(TimetableEntry.id == entry_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Entry not found")
    db.delete(obj)
    db.commit()
    return {"message": "Deleted"}


# ─────────────────────────────────────────────
# Attendance Routes
# ─────────────────────────────────────────────

@app.get("/attendance/today")
async def get_today_attendance(db: Session = Depends(get_db), _=Depends(get_current_user)):
    today = date.today()
    records = db.query(AttendanceRecord).filter(AttendanceRecord.date == today).all()
    result = []
    for r in records:
        result.append({
            "id": r.id,
            "student_id": r.student_id,
            "student_name": r.student.name if r.student else "",
            "roll_number": r.student.roll_number if r.student else "",
            "subject_name": r.subject.name if r.subject else "",
            "date": r.date.isoformat(),
            "status": r.status,
            "is_fake_eye": r.is_fake_eye,
            "confidence": r.confidence,
            "timestamp": r.timestamp.isoformat(),
        })
    return result


@app.get("/attendance")
async def get_attendance(
    attendance_date: Optional[str] = None,
    student_id: Optional[int] = None,
    subject_id: Optional[int] = None,
    staff_id: Optional[int] = None,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    _=Depends(get_current_user),
):
    query = db.query(AttendanceRecord)
    if attendance_date:
        try:
            d = datetime.strptime(attendance_date, "%Y-%m-%d").date()
            query = query.filter(AttendanceRecord.date == d)
        except ValueError:
            pass
    if student_id:
        query = query.filter(AttendanceRecord.student_id == student_id)
    if subject_id:
        query = query.filter(AttendanceRecord.subject_id == subject_id)
    if staff_id:
        query = query.filter(AttendanceRecord.staff_id == staff_id)
    records = query.order_by(AttendanceRecord.timestamp.desc()).offset(skip).limit(limit).all()
    result = []
    for r in records:
        result.append({
            "id": r.id,
            "student_id": r.student_id,
            "student_name": r.student.name if r.student else "",
            "roll_number": r.student.roll_number if r.student else "",
            "subject_name": r.subject.name if r.subject else "",
            "date": r.date.isoformat(),
            "status": r.status,
            "is_fake_eye": r.is_fake_eye,
            "confidence": r.confidence,
            "timestamp": r.timestamp.isoformat(),
        })
    return result


@app.post("/attendance/manual")
async def mark_manual_attendance(
    req: ManualAttendanceRequest,
    db: Session = Depends(get_db),
    _=Depends(get_current_user),
):
    student = db.query(Student).filter(Student.id == req.student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    record = AttendanceRecord(
        student_id=req.student_id,
        subject_id=req.subject_id,
        staff_id=req.staff_id,
        date=date.today(),
        status=req.status,
        confidence=req.confidence,
        is_fake_eye=False,
    )
    db.add(record)
    db.commit()
    return {"message": "Attendance recorded", "id": record.id}


@app.post("/attendance/iris")
async def mark_iris_attendance(
    req: IrisAttendanceRequest,
    db: Session = Depends(get_db),
    _=Depends(get_current_user),
):
    """Mark attendance based on iris scan result. If fake eye detected, mark absent."""
    student = db.query(Student).filter(Student.id == req.student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    if not student.is_enrolled:
        raise HTTPException(status_code=400, detail="Student iris not enrolled")

    status_val = "absent" if req.is_fake_eye else "present"

    record = AttendanceRecord(
        student_id=req.student_id,
        subject_id=req.subject_id,
        staff_id=req.staff_id,
        date=date.today(),
        status=status_val,
        confidence=req.confidence,
        is_fake_eye=req.is_fake_eye,
    )
    db.add(record)
    db.commit()
    return {
        "message": "Iris attendance recorded",
        "status": status_val,
        "is_fake_eye": req.is_fake_eye,
        "id": record.id,
    }


@app.get("/attendance/stats/today")
async def get_today_stats(db: Session = Depends(get_db), _=Depends(get_current_user)):
    today = date.today()
    total = db.query(AttendanceRecord).filter(AttendanceRecord.date == today).count()
    present = db.query(AttendanceRecord).filter(
        AttendanceRecord.date == today, AttendanceRecord.status == "present"
    ).count()
    absent = db.query(AttendanceRecord).filter(
        AttendanceRecord.date == today, AttendanceRecord.status == "absent"
    ).count()
    fake_eye = db.query(AttendanceRecord).filter(
        AttendanceRecord.date == today, AttendanceRecord.is_fake_eye == True
    ).count()
    total_students = db.query(Student).count()
    return {
        "date": today.isoformat(),
        "total_students": total_students,
        "total_records": total,
        "present": present,
        "absent": absent,
        "fake_eye_detected": fake_eye,
    }


# ─────────────────────────────────────────────
# Dashboard Stats
# ─────────────────────────────────────────────

@app.get("/admin/dashboard/stats")
async def get_dashboard_stats(db: Session = Depends(get_db), _=Depends(get_current_user)):
    today = date.today()
    return {
        "total_students": db.query(Student).count(),
        "total_staff": db.query(Staff).count(),
        "today_attendance": db.query(AttendanceRecord).filter(
            AttendanceRecord.date == today, AttendanceRecord.status == "present"
        ).count(),
        "total_subjects": db.query(Subject).count(),
        "total_departments": db.query(Department).count(),
        "total_admins": db.query(AdminUser).count(),
        "total_cameras": 0,
        "recent_attendance": [],
    }


# ─────────────────────────────────────────────
# ML Iris Recognition Endpoints
# ─────────────────────────────────────────────

@app.get("/ml/status")
async def ml_status(_=Depends(get_current_user)):
    """Check if the ML iris engine is available and loaded."""
    enrolled_count = 0
    try:
        db = SessionLocal()
        enrolled_count = db.query(Student).filter(
            Student.iris_feature_left.isnot(None)
        ).count()
        db.close()
    except Exception:
        pass
    return {
        "ml_available": ML_AVAILABLE,
        "engine_ready": _iris_engine is not None and (_iris_engine.is_ready() if _iris_engine else False),
        "enrolled_students": enrolled_count,
        "model": "MediaPipe FaceMesh + Gabor IrisCode",
        "threshold": 0.32,
    }


@app.post("/iris/scan")
async def scan_iris(
    image: UploadFile = File(...),
    subject_id: Optional[int] = Form(None),
    staff_id: Optional[int] = Form(None),
    mark_attendance: bool = Form(True),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """
    Full iris scan pipeline:
      1. Accept image upload
      2. Detect iris using MediaPipe
      3. Fake-eye liveness check
      4. Extract Gabor IrisCode features
      5. Match against all enrolled students (Hamming distance)
      6. Optionally mark attendance automatically

    Returns: matched student info + confidence + liveness details
    """
    if not ML_AVAILABLE or _iris_engine is None:
        raise HTTPException(
            status_code=503,
            detail="ML engine not available. Install: pip install mediapipe opencv-python"
        )

    # Read the uploaded image
    image_bytes = await image.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="Empty image uploaded")

    # Load all enrolled students' iris features
    enrolled_students = db.query(Student).filter(
        (Student.iris_feature_left.isnot(None)) |
        (Student.iris_feature_right.isnot(None))
    ).all()

    enrolled_list = [
        EnrolledIris(
            student_id=s.id,
            student_name=s.name,
            roll_number=s.roll_number,
            feature_left=s.iris_feature_left,
            feature_right=s.iris_feature_right,
        )
        for s in enrolled_students
    ]

    # Run the full pipeline
    result = _iris_engine.scan(image_bytes, enrolled_list)

    # Build response
    response = {
        "eye_detected":     result.eye_detected,
        "is_fake_eye":      result.is_fake_eye,
        "liveness_score":   result.liveness_score,
        "matched":          result.matched,
        "student_id":       result.student_id,
        "student_name":     result.student_name,
        "roll_number":      result.roll_number,
        "confidence":       result.confidence,
        "hamming_distance": result.hamming_distance,
        "message":          result.message,
        "attendance_marked": False,
    }

    # Auto-mark attendance if matched and not fake eye
    if result.matched and not result.is_fake_eye and mark_attendance:
        try:
            record = AttendanceRecord(
                student_id=result.student_id,
                staff_id=staff_id,
                subject_id=subject_id,
                date=date.today(),
                status="present",
                is_fake_eye=False,
                confidence=result.confidence,
                timestamp=datetime.utcnow(),
            )
            db.add(record)
            db.commit()
            response["attendance_marked"] = True
            logger.info(
                f"Auto attendance: {result.student_name} "
                f"({result.roll_number}) — {result.confidence:.1%}"
            )
        except Exception as e:
            logger.error(f"Failed to mark attendance: {e}")
            db.rollback()

    elif result.is_fake_eye:
        # Mark as fake-eye attempt
        try:
            if result.student_id:  # if we can identify who is trying
                record = AttendanceRecord(
                    student_id=result.student_id,
                    staff_id=staff_id,
                    subject_id=subject_id,
                    date=date.today(),
                    status="absent",
                    is_fake_eye=True,
                    confidence=0.0,
                    timestamp=datetime.utcnow(),
                )
                db.add(record)
                db.commit()
        except Exception:
            db.rollback()

    return response


# ─────────────────────────────────────────────
# Legacy / compat endpoints
# ─────────────────────────────────────────────

@app.get("/students")
async def get_students_legacy(db: Session = Depends(get_db), _=Depends(get_current_user)):
    return await list_students(db=db, _=_)


@app.get("/cameras")
async def get_cameras(_=Depends(get_current_user)):
    return []


@app.get("/service/status")
async def get_service_status(_=Depends(get_current_user)):
    return {"attendance_service": "running", "iris_recognition": "ready", "database": "connected"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8001, reload=True)
