# Copyright 2025 Cloud LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv

# Load environment variables from .env file in the app directory
env_path = Path(__file__).parent / ".env"
load_dotenv(dotenv_path=env_path)

# Authentication Configuration:
# MiOS v2.1.0: Support both AI Studio (API Key) and Vertex AI (GCP).
if os.getenv("GOOGLE_API_KEY"):
    # AI Studio mode: Use the provided API key
    os.environ["GOOGLE_GENAI_USE_VERTEXAI"] = "False"
else:
    # Vertex AI mode: Use GCP credentials (DEFAULT)
    os.environ["GOOGLE_GENAI_USE_VERTEXAI"] = "True"
    os.environ["GOOGLE_CLOUD_PROJECT"] = "976341856950"
    os.environ["GOOGLE_CLOUD_LOCATION"] = "us-east1"


@dataclass
class ResearchConfiguration:
    """Configuration for research-related models and parameters.

    Attributes:
        critic_model (str): Model for evaluation tasks.
        worker_model (str): Model for working/generation tasks.
        max_search_iterations (int): Maximum search iterations allowed.
    """

    critic_model: str = .ai/agent-state-1.5-flash"
    worker_model: str = .ai/agent-state-1.5-flash"
    max_search_iterations: int = 5


config = ResearchConfiguration()
