import os
import shutil
import re
from langchain_community.vectorstores import Chroma
from langchain_community.embeddings import HuggingFaceEmbeddings
from langchain_text_splitters import RecursiveCharacterTextSplitter


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    data_path = os.path.join(script_dir, "formatted_schemes.txt")
    chroma_path = os.path.join(script_dir, "chroma_db")

    print("Loading file...")

    with open(data_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Properly split by full separator line
    schemes = re.split(r"\n={10,}\n", content)

    # Remove empty entries
    schemes = [s.strip() for s in schemes if s.strip()]

    print(f"Total scheme blocks found: {len(schemes)}")

    # Light internal splitting (only if very large)
    splitter = RecursiveCharacterTextSplitter(
        chunk_size=3000,
        chunk_overlap=200,
        separators=["\n### ", "\n\n"]
    )

    documents = splitter.create_documents(schemes)

    print(f"Final chunk count: {len(documents)}")

    # Remove old DB
    if os.path.exists(chroma_path):
        shutil.rmtree(chroma_path)
        print("Old database deleted.")

    print("Generating embeddings locally...")

    embedding = HuggingFaceEmbeddings(
        model_name="sentence-transformers/all-MiniLM-L6-v2"
    )

    db = Chroma.from_documents(
        documents=documents,
        embedding=embedding,
        persist_directory=chroma_path
    )

    print("✅ Database rebuilt successfully!")


if __name__ == "__main__":
    main()
