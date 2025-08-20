
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uvicorn
import os
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Insight-Agent",
    description="AI-powered text analysis service",
    version="1.0.0"
)

class TextAnalysisRequest(BaseModel):
    text: str

class TextAnalysisResponse(BaseModel):
    original_text: str
    word_count: int
    character_count: int
    sentence_count: int

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "insight-agent"}

@app.post("/analyze", response_model=TextAnalysisResponse)
async def analyze_text(request: TextAnalysisRequest):
    try:
        text = request.text.strip()
        
        if not text:
            raise HTTPException(status_code=400, detail="Text cannot be empty")
        
        # Basic text analysis
        word_count = len(text.split())
        character_count = len(text)
        sentence_count = text.count('.') + text.count('!') + text.count('?')
        
        logger.info(f"Analyzed text with {word_count} words")
        
        return TextAnalysisResponse(
            original_text=text,
            word_count=word_count,
            character_count=character_count,
            sentence_count=max(1, sentence_count)  # At least 1 sentence
        )
    
    except Exception as e:
        logger.error(f"Analysis failed: {str(e)}")
        raise HTTPException(status_code=500, detail="Analysis failed")

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)