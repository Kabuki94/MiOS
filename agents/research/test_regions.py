import os
import google.auth
import vertexai
from vertexai.generative_models import GenerativeModel

def test_models():
    project_id = "mios-kabu-ki-io"
    regions = ["us-central1", "us-east4", "europe-west1", "europe-west4", "asia-northeast1", "us-east1"]
    
    models = [.ai/agent-state-1.5-flash", .ai/agent-state-1.5-pro"]
    
    for region in regions:
        print(f"--- Testing Region: {region} ---")
        vertexai.init(project=project_id, location=region)
        for model_name in models:
            try:
                model = GenerativeModel(model_name)
                response = model.generate_content("Hi")
                print(f"✅ {model_name} in {region} success!")
            except Exception as e:
                print(f"❌ {model_name} in {region} failed: {str(e)[:100]}")

if __name__ == "__main__":
    test_models()
