# Hume AI Migration Summary

## ✅ Completed Changes

### Backend (`backend/main.py`)
- ✅ Removed Retell SDK dependency (`from retell import AsyncRetell`)
- ✅ Added Hume AI API integration using `httpx`
- ✅ Created `/hume/create-session` endpoint that:
  - Creates a new EVI session
  - Returns `session_id`, `websocket_url`, and `api_key`
  - Includes user's todos and screen time limit in initial message
- ✅ Updated webhook endpoint to `/hume-webhook` (for future use)

### iOS App
- ✅ Created `HumeCallManager.swift`:
  - Handles WebSocket connection to Hume EVI
  - Manages audio input/output (16kHz, 16-bit PCM)
  - Processes Hume's message format (audio_output, user_message, assistant_message)
  - Handles session lifecycle
- ✅ Updated `NetworkManager.swift`:
  - Changed `createWebCall()` → `createHumeSession()`
  - Now calls `/hume/create-session` endpoint
- ✅ Updated `ContentView.swift`:
  - Replaced `RetellCallManager` with `HumeCallManager`
  - Updated state variables (`sessionId`, `websocketURL`, `apiKey`)
  - Updated `startVoiceCall()` to use Hume session creation

## 🔧 Required Setup

### 1. Backend Environment Variables
Add to your `backend/.env` file:
```bash
HUME_API_KEY=your_hume_api_key_here
# Optional: If you have a custom EVI config
HUME_EVI_CONFIG_ID=your_config_id_here
```

### 2. Install Backend Dependencies
The backend now uses `httpx` instead of Retell SDK. Make sure it's installed:
```bash
cd backend
pip install httpx
```

### 3. Remove Old Retell Files (Optional Cleanup)
You can delete these files as they're no longer needed:
- `ai_anti_doomscroll/ai_anti_doomscroll/RetellCallManager.swift`
- `ai_anti_doomscroll/ai_anti_doomscroll/RetellWebViewManager.swift`

## 🎯 How It Works Now

1. **User clicks "Talk to AI" button** → `startVoiceCall()` is called
2. **Backend creates Hume session** → Returns WebSocket URL + API key
3. **iOS connects to Hume WebSocket** → Authenticates with API key
4. **Audio streams bidirectionally**:
   - Mic → Hume (as base64-encoded audio in JSON messages)
   - Hume → Speaker (audio_output messages)
5. **Transcript updates** → Real-time via `user_message` and `assistant_message` events

## 📝 Notes

- **Hume EVI uses 16kHz audio** (vs Retell's 24kHz) - already configured
- **Message format**: Hume uses JSON messages with `type` field (audio_input, audio_output, etc.)
- **Session management**: Hume generates session IDs automatically
- **Initial context**: Your todos and screen time limit are sent in the initial message

## 🚀 Next Steps

1. **Add your Hume API key** to `backend/.env`
2. **Test the connection** - Tap the "Test AI Call" button
3. **Verify audio works** - You should hear the AI and see transcripts
4. **Optional**: Configure a custom EVI config in Hume dashboard for better conversation flow

## ⚠️ Important

The Hume API endpoint structure may need adjustment based on their actual API documentation. If you encounter connection issues, check:
- Hume's official API docs for the exact WebSocket URL format
- Whether they require additional headers or authentication
- The exact message format for audio input/output

Let me know if you need any adjustments or if you encounter issues!
