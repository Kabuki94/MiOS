import os
import vertexai
from vertexai.generative_models import GenerativeModel

def test_models():
    project_id = "cloudws-os"
    region = "us-central1"
    
    models = ["gemini-1.5-flash-001", "gemini-1.5-pro-001", "gemini-1.5-flash-002", "gemini-1.5-pro-002", "gemini-2.0-flash-001"]
    
    vertexai.init(project=project_id, location=region)
    for model_name in models:
        try:
            model = GenerativeModel(model_name)
            response = model.generate_content("Hi")
            print(f"✅ {model_name} success!")
        except Exception as e:
            print(f"❌ {model_name} failed: {str(e)[:100]}")

if __name__ == "__main__":
    test_models()
