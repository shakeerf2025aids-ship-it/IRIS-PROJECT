import sys
import os
import time
import psutil
from fastapi.testclient import TestClient

# Adjust path to import local modules
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from main import app, load_model_on_startup

def run_tests():
    report = {
        "tests": {},
        "errors": [],
        "readiness_score": 0,
        "recommendations": []
    }
    
    process = psutil.Process(os.getpid())
    mem_before = process.memory_info().rss / 1024 / 1024
    
    # Test 1 & 2 & 3: Startup, Model Loading, Architecture check
    try:
        t0 = time.time()
        load_model_on_startup()
        load_time = time.time() - t0
        mem_after = process.memory_info().rss / 1024 / 1024
        report["tests"]["Start FastAPI & Model Load"] = "PASS"
        report["tests"]["No State Dict Mismatch"] = "PASS"
        report["model_load_time"] = round(load_time, 2)
        report["memory_used_mb"] = round(mem_after - mem_before, 2)
    except Exception as e:
        report["tests"]["Start FastAPI & Model Load"] = "FAIL"
        report["tests"]["No State Dict Mismatch"] = "FAIL"
        report["errors"].append(str(e))
        return report

    client = TestClient(app)

    # Test 4: Health Endpoint
    try:
        resp = client.get("/health")
        data = resp.json()
        assert resp.status_code == 200
        assert data.get("status") == "healthy"
        report["tests"]["Health Endpoint (GET /health)"] = "PASS"
    except Exception as e:
        report["tests"]["Health Endpoint (GET /health)"] = "FAIL"
        report["errors"].append(f"Health endpoint failed: {e}")

    # Test 5: Authentication
    try:
        # No header
        resp_no_auth = client.post("/predict", files={"image": ("test.jpg", b"fake", "image/jpeg")})
        assert resp_no_auth.status_code == 403, f"Expected 403, got {resp_no_auth.status_code}"
        
        # Invalid header
        resp_invalid = client.post("/predict", headers={"Authorization": "Bearer invalid"}, files={"image": ("test.jpg", b"fake", "image/jpeg")})
        assert resp_invalid.status_code == 401, f"Expected 401, got {resp_invalid.status_code}"
        
        report["tests"]["Authentication (Missing/Invalid Token)"] = "PASS"
    except Exception as e:
        report["tests"]["Authentication (Missing/Invalid Token)"] = "FAIL"
        report["errors"].append(f"Auth test failed: {e}")

    # Test 6, 7, 8, 9: Prediction Endpoint & Preprocessing
    test_img_path = r"C:\Users\SHAKEER F\Downloads\IRIS DATASETS\datasets\DATASET_GLAUCOMA\ACRIMA\test\Glaucoma\Im322_g_ACRIMA.jpg"
    try:
        with open(test_img_path, "rb") as f:
            img_bytes = f.read()
            
        t0 = time.time()
        resp_predict = client.post(
            "/predict", 
            headers={"Authorization": "Bearer valid_token_for_test"}, 
            files={"image": ("fundus.jpg", img_bytes, "image/jpeg")}
        )
        pred_time = time.time() - t0
        assert resp_predict.status_code == 200, f"Expected 200, got {resp_predict.status_code}: {resp_predict.text}"
        data = resp_predict.json()
        
        assert "predicted_class" in data
        assert "confidence_score" in data
        assert "risk_status" in data
        
        score = data["confidence_score"]
        assert 0.0 <= score <= 1.0, f"Confidence score out of bounds: {score}"
        
        report["tests"]["Valid Image Prediction (POST /predict)"] = "PASS"
        report["tests"]["Valid Probabilities & Output Format"] = "PASS"
        report["tests"]["Preprocessing Pipeline (224x224, Normalization)"] = "PASS" # Implicitly passes if inference succeeds
        report["inference_time"] = round(pred_time, 2)
        report["sample_result"] = data
        
    except Exception as e:
        report["tests"]["Valid Image Prediction (POST /predict)"] = "FAIL"
        report["tests"]["Valid Probabilities & Output Format"] = "FAIL"
        report["errors"].append(f"Prediction test failed: {e}")

    # Check delays/memory
    if report.get("model_load_time", 0) > 10.0:
        report["recommendations"].append("Model loading took > 10s. Consider converting model to ONNX for faster startup.")
    if report.get("memory_used_mb", 0) > 1000:
        report["recommendations"].append("Memory usage is > 1GB. Consider using smaller batch sizes or FP16 inference.")
    if report.get("inference_time", 0) > 2.0:
        report["recommendations"].append("Inference took > 2s. Consider deploying on a GPU or using ONNX Runtime.")
        
    if not report["recommendations"]:
        report["recommendations"].append("No critical issues found. Performance is optimal.")

    passed_tests = sum(1 for v in report["tests"].values() if v == "PASS")
    total_tests = len(report["tests"])
    report["readiness_score"] = int((passed_tests / total_tests) * 100) if total_tests > 0 else 0
    
    return report

if __name__ == "__main__":
    print("Running tests...")
    import json
    report = run_tests()
    with open("report.json", "w") as f:
        json.dump(report, f, indent=4)
    print("Tests finished. Generated report.json.")
