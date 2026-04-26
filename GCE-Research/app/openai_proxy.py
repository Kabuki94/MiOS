import os
import json
import httpx
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import List, Optional, Dict, Any

app = FastAPI(title="MiOS OpenAI-ADK Proxy")

ADK_SERVER_URL = os.getenv("ADK_SERVER_URL", "http://127.0.0.1:8000")
AGENT_NAME = "app"  # Default agent name in GCE-Research

class OpenAIMessage(BaseModel):
    role: str
    content: str

class OpenAICompletionRequest(BaseModel):
    model: str
    messages: List[OpenAIMessage]
    stream: Optional[bool] = False
    temperature: Optional[float] = 0.7

@app.post("/v1/chat/completions")
async def chat_completions(request: OpenAICompletionRequest):
    # 1. Extract the last user message as the "prompt" for ADK
    user_prompt = ""
    for msg in reversed(request.messages):
        if msg.role == "user":
            user_prompt = msg.content
            break
    
    if not user_prompt:
        raise HTTPException(status_code=400, detail="No user message found in request")

    # 2. Forward to ADK API Server
    # ADK typically uses /agents/{agent_name}/sessions/{session_id}/run
    # For simplicity, we'll use a new session for every request or track session_id in the 'model' field
    session_id = "default-session"
    adk_run_url = f"{ADK_SERVER_URL}/agents/{AGENT_NAME}/sessions/{session_id}/run"

    adk_payload = {
        "input": user_prompt
    }

    async def generate():
        async with httpx.AsyncClient(timeout=60.0) as client:
            try:
                # ADK run returns a stream of events
                async with client.stream("POST", adk_run_url, json=adk_payload) as response:
                    if response.status_code != 200:
                        error_text = await response.aread()
                        yield f"data: {json.dumps({'error': error_text.decode()})}\n\n"
                        return

                    full_response_text = ""
                    async for line in response.aiter_lines():
                        if not line.strip(): continue
                        if line.startswith("data: "):
                            try:
                                event = json.loads(line[6:])
                                # ADK event structure: look for 'content' or final output
                                if "content" in event:
                                    content_chunk = event["content"]
                                    full_response_text += content_chunk
                                    
                                    # Translate to OpenAI stream format
                                    chunk = {
                                        "id": "chatcmpl-mios",
                                        "object": "chat.completion.chunk",
                                        "created": 1234567,
                                        "model": request.model,
                                        "choices": [{
                                            "index": 0,
                                            "delta": {"content": content_chunk},
                                            "finish_reason": None
                                        }]
                                    }
                                    yield f"data: {json.dumps(chunk)}\n\n"
                            except:
                                pass
                    
                    # End of stream
                    yield "data: [DONE]\n\n"
            except Exception as e:
                yield f"data: {json.dumps({'error': str(e)})}\n\n"

    if request.stream:
        return StreamingResponse(generate(), media_type="text/event-stream")
    else:
        # Non-streaming: accumulate and return
        accumulated_text = ""
        async for chunk_str in generate():
            if chunk_str.startswith("data: ") and not chunk_str.strip() == "data: [DONE]":
                try:
                    chunk_json = json.loads(chunk_str[6:])
                    if "choices" in chunk_json:
                        accumulated_text += chunk_json["choices"][0]["delta"].get("content", "")
                except:
                    pass
        
        return {
            "id": "chatcmpl-mios",
            "object": "chat.completion",
            "created": 1234567,
            "model": request.model,
            "choices": [{
                "index": 0,
                "message": {"role": "assistant", "content": accumulated_text},
                "finish_reason": "stop"
            }],
            "usage": {"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0}
        }

@app.get("/v1/models")
async def list_models():
    return {
        "object": "list",
        "data": [
            {"id": "mios-research-agent", "object": "model", "created": 1234567, "owned_by": "kabu.ki"}
        ]
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
