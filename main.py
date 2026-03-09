import os
import uvicorn
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from query_database import ask

app = FastAPI(title="Farmer Buddy API")

# Store chat histories per session
chat_histories = {}

class ChatRequest(BaseModel):
    question: str
    session_id: str = "default_user"

@app.get("/")
async def root():
    return {"status": "Farmer Buddy API is running"}

@app.post("/chat")
async def chat_endpoint(request: ChatRequest):
    try:
        # Get history for session, defaulting to an empty list
        history = chat_histories.get(request.session_id, [])

        # Force history to be a list to prevent the 'tuple' append crash
        if not isinstance(history, list):
            history = list(history)

        # Call RAG function from query_database.py
        answer, updated_history = ask(request.question, history)

        # Store last 10 messages only to manage memory on Render's free tier
        chat_histories[request.session_id] = updated_history[-10:]

        return {"answer": answer}

    except Exception as e:
        # This will print the exact error in your Render logs for debugging
        print(f"Server Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/chat/clear")
async def clear_chat(session_id: str = "default_user"):
    if session_id in chat_histories:
        chat_histories[session_id] = []
        return {"message": "Chat history cleared"}
    return {"message": "No history found to clear"}

if __name__ == "__main__":
    # Render provides a PORT environment variable; fallback to 8000 for local testing
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)