#!/usr/bin/env python3
import os
import sys
import json
import re
import google.generativeai as genai
from PIL import Image

def judge_image(image_path, original_prompt, api_key):
    genai.configure(api_key=api_key)
    
    # Use Gemini 1.5 Flash for judging (it's fast and has vision)
    model = genai.GenerativeModel(model_name="gemini-1.5-flash")
    
    try:
        img = Image.open(image_path)
    except Exception as e:
        return {"error": f"Could not open image: {e}"}

    analysis_prompt = f"""
    Sei un araldo della veridicità e critico d'arte digitale. Il tuo compito è giudicare un'immagine generata da un'IA.
    
    PROMPT ORIGINALE: "{original_prompt}"
    
    Analizza l'immagine allegata e valuta:
    1. Fedeltà al Prompt: Tutti gli elementi (città, oggetti, scritte) sono presenti?
    2. Precisione Geografica: Se il prompt specifica posizioni (es. Modena a sinistra di Bologna), verifica che siano corrette.
    3. Somiglianza: Se richiesto un personaggio noto (es. Guccini), la somiglianza è adeguata?
    4. Qualità Estetica: Luci, ombre, stile (Pixar/Diorama).
    
    REGOLE DI RISPOSTA:
    Restituisci ESCLUSIVAMENTE un oggetto JSON valido con questo formato:
    {{
      "score": <float tra 1.0 e 10.0>,
      "actionable_feedback": "<stringa in italiano con consigli precisi per migliorare il prompt o la generazione>"
    }}
    
    Sii un giudice severo: se le città sono invertite o il volto non somiglia, non superare il 6.0.
    """

    try:
        response = model.generate_content([analysis_prompt, img])
        # Extract JSON using regex to handle potential markdown wrappers
        match = re.search(r'\{.*\}', response.text, re.DOTALL)
        if match:
            return json.loads(match.group(0))
        else:
            return {"error": "No JSON found in response", "raw": response.text}
    except Exception as e:
        return {"error": f"API Error: {e}"}

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: image_judge.py <image_path> <prompt>")
        sys.exit(1)
        
    img_path = sys.argv[1]
    prompt = sys.argv[2]
    api_key = os.environ.get("GEMINI_API_KEY")
    
    if not api_key:
        # Try to extract from .env if not in env
        env_path = os.path.expanduser("~/.hermes/.env")
        if os.path.exists(env_path):
            with open(env_path, 'r') as f:
                for line in f:
                    if "GEMINI_API_KEY" in line:
                        api_key = line.split('=')[1].strip().strip("'").strip('"')
                        break
    
    if not api_key:
        print(json.dumps({"error": "GEMINI_API_KEY not found"}))
        sys.exit(1)
        
    result = judge_image(img_path, prompt, api_key)
    print(json.dumps(result, indent=2, ensure_ascii=False))
