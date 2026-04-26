from vertexai import Client, types
import sys

def main():
    try:
        client = Client(project="cloudws-os", location="us-central1")

        config = {
            "config_path": "gs://mios-vertex-autogen-cloudws-os/configs/config-1.json",
            "service_account": "vertex-express@cloudws-os.iam.gserviceaccount.com"
        }

        print(f"🚀 Launching Vertex AI Prompt Optimization job with config: {config}")
        job = client.prompts.launch_optimization_job(
            method=types.PromptOptimizerMethod.VAPO,
            config=config
        )
        print(f"⏳ Job requested. Waiting for initial state...")
        print(f"✅ Job launched successfully!")
        print(f"Job Name: {job.name}")
        print(f"State: {job.state}")
        
    except Exception as e:
        print(f"❌ Error launching job: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
