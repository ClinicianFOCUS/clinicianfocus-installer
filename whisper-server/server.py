# This software is released under the AGPL-3.0 license

from torch._C import NoneType
from fastapi import FastAPI, File, UploadFile, HTTPException, Security
from fastapi.security import APIKeyHeader 
from pydantic import BaseModel
from dotenv import load_dotenv
import whisper
import uvicorn
import os
import tempfile
import argparse
import secrets

load_dotenv()

# Initialize Whisper model
model = NoneType
sessionApiKey = NoneType

app = FastAPI()
api_key_header = APIKeyHeader(name="X-API-Key")

class TranscriptionResponse(BaseModel):
    text: str

def generate_api_key():
    return secrets.token_urlsafe(32)

def get_api_key(api_key_header: str = Security(api_key_header)) -> str:
    if api_key_header == sessionApiKey:
        return api_key_header
    raise HTTPException(
        status_code=401,
        detail="Invalid or missing API Key",
    )

def check_api_key():
    api_key = os.getenv('SESSION_API_KEY')

    if not api_key:
        # If not found, generate a new one and store it in the environment
        api_key = generate_api_key()
        with open(".env", "a") as f:
            f.write(f"SESSION_API_KEY={api_key}\n")
    
    return api_key

@app.post("/whisperaudio", response_model=TranscriptionResponse)
async def transcribe_audio(file: UploadFile = File(...), api_key: str = Security(get_api_key)):
    
    if file.content_type != "audio/mpeg" and file.content_type != "audio/wav":
        raise HTTPException(status_code=400, detail="Invalid content type. Please upload an audio file.")

    # Save the audio file temporarily
    try:
        with tempfile.NamedTemporaryFile(delete=False) as temp_audio_file:
            contents = await file.read()
            temp_audio_file.write(contents)
            temp_file_path = temp_audio_file.name

        # Process the file with Whisper
        result = model.transcribe(temp_file_path)
        response_data = {"text": result["text"]}

    except OSError as e:
        raise HTTPException(status_code=500, detail=f"Error processing audio file: {e}")
    except IOError as e:
        raise HTTPException(status_code=500, detail=f"Error processing audio file: {e}")
    except AttributeError as e:
        raise HTTPException(status_code=500, detail=f"Error processing audio file: {e}")
    except TypeError as e:
        raise HTTPException(status_code=500, detail=f"Error processing audio file: {e}")
    except ValueError as e:
        raise HTTPException(status_code=500, detail=f"Error processing audio file: {e}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error processing audio file: {e}")

    finally:
        # Clean up the temporary file
        if os.path.exists(temp_file_path):
            os.remove(temp_file_path)

    return response_data

if __name__ == '__main__':
    # Command-line argument parsing
    parser = argparse.ArgumentParser(description="FastAPI server for Whisper audio transcription")
    parser.add_argument("--host", type=str, default="0.0.0.0", help="Host address to run the server on")
    parser.add_argument("--port", type=int, default=2224, help="Port number to run the server on")
    parser.add_argument("--whispermodel", type=str, default="medium", help="Whisper model to use for transcription (https://github.com/openai/whisper?tab=readme-ov-file#available-models-and-languages)")

    args = parser.parse_args()

    model = whisper.load_model(args.whispermodel)
    sessionApiKey = check_api_key()

    print(f"Use this API key for requests: {sessionApiKey}")

    uvicorn.run(app, host=args.host, port=args.port)
