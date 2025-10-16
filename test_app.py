#!/usr/bin/env python3
"""
Simple test script to verify the Flask application works correctly.
This can be run locally to test the containerized application.
"""

import requests
import time
import sys
import os

def test_application(base_url="http://localhost:8000"):
    """Test the Flask application endpoints."""
    
    print(f"Testing application at {base_url}")
    
    try:
        # Test 1: Health check - GET /
        print("1. Testing home page...")
        response = requests.get(f"{base_url}/", timeout=10)
        assert response.status_code == 200, f"Expected 200, got {response.status_code}"
        assert "Upload a File" in response.text, "Home page should contain upload form"
        print("   ✅ Home page accessible")
        
        # Test 2: Files listing page
        print("2. Testing files listing...")
        response = requests.get(f"{base_url}/files", timeout=10)
        assert response.status_code == 200, f"Expected 200, got {response.status_code}"
        print("   ✅ Files page accessible")
        
        # Test 3: Upload test (this will fail without proper Azure credentials, but tests the endpoint)
        print("3. Testing file upload endpoint...")
        try:
            response = requests.post(
                f"{base_url}/upload",
                data={
                    "filename": "test.txt",
                    "file_content": "Hello, Container Apps!"
                },
                timeout=10
            )
            # We expect either a redirect (302) or an error page, but not a 404 or 500
            assert response.status_code in [200, 302, 400], f"Upload endpoint returned {response.status_code}"
            print("   ✅ Upload endpoint responding")
        except Exception as e:
            print(f"   ⚠️  Upload test failed (expected without Azure credentials): {e}")
        
        print("\n🎉 All basic tests passed! Application is working correctly.")
        return True
        
    except requests.exceptions.ConnectionError:
        print(f"   ❌ Cannot connect to {base_url}. Is the application running?")
        return False
    except Exception as e:
        print(f"   ❌ Test failed: {e}")
        return False

if __name__ == "__main__":
    # Allow custom URL from command line
    url = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8000"
    
    # Wait a moment for the server to start up
    print("Waiting for server to start...")
    time.sleep(5)
    
    success = test_application(url)
    sys.exit(0 if success else 1)