import os
from langchain_community.vectorstores import Chroma
from langchain_community.embeddings import HuggingFaceEmbeddings
from groq import Groq
from dotenv import load_dotenv

load_dotenv()

# -------------------------
# CONFIG
# -------------------------
GROQ_API_KEY = os.getenv("GROQ_API_KEY")
MODEL_NAME = "llama-3.1-8b-instant"

script_dir = os.path.dirname(os.path.abspath(__file__))
CHROMA_PATH = os.path.join(script_dir, "chroma_db")

# -------------------------
# INITIALIZE MODELS
# -------------------------
print("Loading embedding model...")
embedding = HuggingFaceEmbeddings(
    model_name="sentence-transformers/all-MiniLM-L6-v2"
)

print("Loading Chroma database...")
db = Chroma(
    persist_directory=CHROMA_PATH,
    embedding_function=embedding
)

print("Connecting to Groq...")
client = Groq(api_key=GROQ_API_KEY)

# -------------------------
# RAG FUNCTION WITH MEMORY
# -------------------------

def ask(question, history=None):
    """
    Takes a question and previous conversation history.
    Returns (answer, updated_history).
    """

    # Safe history initialization
    if history is None:
        history = []

    # 1️⃣ Retrieve relevant context
    docs = db.similarity_search(question, k=8)
    context = "\n\n".join([doc.page_content for doc in docs])

    # 2️⃣ Create message list (IMPORTANT: No trailing comma)
    messages = [
        {
            "role": "system",
            "content": (
                "You are 'Farmer Buddy', a helpful and polite agricultural assistant. "
                "Your goal is to explain government schemes to farmers in a very simple way.\n\n"
                "Rules:\n"
                "1. Use ONLY the provided context. If the answer isn't there, say you don't know yet.\n"
                "2. Structure your answer with headings like: '📋 Scheme Name', "
                "'✅ Benefits', and '📝 How to Apply'.\n"
                "3. Use bullet points for steps and requirements.\n"
                "4. Be friendly and encouraging.\n"
                "5. Keep language simple for rural users.\n"
            ),
        }
    ]

    # 3️⃣ Add previous chat history
    messages.extend(history)

    # 4️⃣ Add current user question WITH context
    messages.append({
        "role": "user",
        "content": f"Context:\n{context}\n\nQuestion:\n{question}"
    })

    # 5️⃣ Call Groq LLM
    response = client.chat.completions.create(
        model=MODEL_NAME,
        messages=messages,
    )

    answer = response.choices[0].message.content

    # 6️⃣ Update conversation history
    history.append({"role": "user", "content": question})
    history.append({"role": "assistant", "content": answer})

    return answer, history


# -------------------------
# CLI MODE (Optional Testing)
# -------------------------
if __name__ == "__main__":
    current_history = []
    print("\n--- Farmer Buddy CLI Mode ---")

    while True:
        user_input = input("\nYou: ")
        if user_input.lower() == "exit":
            break

        reply, current_history = ask(user_input, current_history)
        print(f"\nBuddy: {reply}")