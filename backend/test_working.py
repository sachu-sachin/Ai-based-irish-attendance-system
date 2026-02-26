#!/usr/bin/env python3
"""
Test the working system
"""

import requests
import json

def test_system():
    """Test the complete working system"""
    base_url = "http://localhost:8000"
    
    print("🧪 Testing AI Attendance System")
    print("=" * 50)
    
    # Test 1: Health Check
    print("\n1. Testing Health Check...")
    try:
        response = requests.get(f"{base_url}/health")
        if response.status_code == 200:
            print(f"✅ Health Check: {response.json()}")
        else:
            print(f"❌ Health Check: {response.status_code}")
    except Exception as e:
        print(f"❌ Health Check Error: {e}")
    
    # Test 2: Root Endpoint
    print("\n2. Testing Root Endpoint...")
    try:
        response = requests.get(f"{base_url}/")
        if response.status_code == 200:
            print(f"✅ Root: {response.json()}")
        else:
            print(f"❌ Root: {response.status_code}")
    except Exception as e:
        print(f"❌ Root Error: {e}")
    
    # Test 3: Login
    print("\n3. Testing Login...")
    try:
        login_data = {"username": "admin", "password": "admin123"}
        response = requests.post(f"{base_url}/auth/login", json=login_data)
        if response.status_code == 200:
            token_data = response.json()
            print(f"✅ Login Successful: {token_data['user']}")
            token = token_data["access_token"]
            
            # Test 4: Authenticated Endpoints
            print("\n4. Testing Authenticated Endpoints...")
            headers = {"Authorization": f"Bearer {token}"}
            
            endpoints = [
                ("/auth/me", "Current User"),
                ("/admin/dashboard/stats", "Dashboard Stats"),
                ("/students", "Students"),
                ("/attendance/today", "Today's Attendance"),
                ("/cameras", "Cameras"),
                ("/service/status", "Service Status")
            ]
            
            for endpoint, name in endpoints:
                try:
                    response = requests.get(f"{base_url}{endpoint}", headers=headers)
                    if response.status_code == 200:
                        print(f"✅ {name}: Working")
                    else:
                        print(f"❌ {name}: {response.status_code}")
                except Exception as e:
                    print(f"❌ {name}: {e}")
        else:
            print(f"❌ Login Failed: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"❌ Login Error: {e}")
    
    # Test 5: API Documentation
    print("\n5. Testing API Documentation...")
    try:
        response = requests.get(f"{base_url}/docs")
        if response.status_code == 200:
            print("✅ Swagger UI: Available at http://localhost:8000/docs")
        else:
            print(f"❌ Swagger UI: {response.status_code}")
    except Exception as e:
        print(f"❌ Swagger UI Error: {e}")
    
    print("\n" + "=" * 50)
    print("🎉 System Test Complete!")
    print("\n📋 Available Endpoints:")
    print("   • GET  / - Root endpoint")
    print("   • GET  /health - Health check")
    print("   • POST /auth/login - User login")
    print("   • GET  /auth/me - Current user info")
    print("   • GET  /admin/dashboard/stats - Dashboard statistics")
    print("   • GET  /students - Student management")
    print("   • GET  /attendance/today - Today's attendance")
    print("   • GET  /cameras - Camera management")
    print("   • GET  /service/status - Service status")
    print("   • GET  /docs - Swagger UI documentation")
    
    print("\n🔑 Default Login:")
    print("   Username: admin")
    print("   Password: admin123")
    
    print("\n🌐 Open in Browser:")
    print("   • API Documentation: http://localhost:8000/docs")
    print("   • ReDoc: http://localhost:8000/redoc")

if __name__ == "__main__":
    test_system()
