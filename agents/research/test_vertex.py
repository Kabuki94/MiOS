import os
import google.auth
import vertexai
from vertexai.generative_models import GenerativeModel

def test_models():
    _, project_id = google.auth.default()
    print(f"Default Project: {project_id}")
    
    # Force project for this test
    project_id = "mios-kabu-ki-io"
    location = "us-east1"
    
    vertexai.init(project=project_id, location=location)
    
    models = [.ai/agent-state-1.5-flash", .ai/agent-state-1.5-pro", .ai/agent-state-2.0-flash-001"]
    
    for model_name in models:
        try:
            print(f"Testing {model_name}...")
            model = GenerativeModel(model_name)
            response = model.generate_content("Hello, identify yourself.")
            print(f"[OK] {model_name} success: {response.text[:50]}...")
        except Exception as e:
            print(f"[FAIL] {model_name} failed: {e}")

if __name__ == "__main__":
    test_models()
