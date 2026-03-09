import os
import uvicorn
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="Farmer Buddy API")
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
        # THE FIX: We moved the import INSIDE the chat function!
        # This stops the server from freezing during startup.
        from query_database import ask 
        
        history = chat_histories.get(request.session_id, [])
        if not isinstance(history, list):
            history = list(history)

        answer, updated_history = ask(request.question, history)
        chat_histories[request.session_id] = updated_history[-10:]

        return {"answer": answer}

    except Exception as e:
        print(f"Server Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 10000))
    uvicorn.run("main:app", host="0.0.0.0", port=port)