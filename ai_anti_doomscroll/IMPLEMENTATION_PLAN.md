# AI Anti-Doomscroll - Updated Implementation Plan

## 🎯 Key Change: WebRTC Web Calls (No Phone Numbers)

**Important:** This plan uses **Retell's WebRTC Web Call API** for in-app voice interactions. Users do NOT need to use their phone number to talk to the AI agent - all voice interaction happens through WebRTC directly in the iOS app.

- ✅ No phone calls required
- ✅ Pure WebRTC connection from iOS app to Retell
- ✅ Better UX - users talk directly in the app
- ⚠️ Phone number still used for OTP authentication, but NOT for voice calls

## Executive Summary

After reviewing both the iOS app and backend code, I've identified that **Retell SDK is already integrated in the backend**. However, instead of using phone calls (which require phone numbers), we'll use **Retell's WebRTC Web Call API** for in-app voice interactions. This allows users to talk to the AI agent directly through the app without needing their phone number, using WebRTC for real-time audio streaming.

## Current State Analysis

### ✅ What's Already Working

**Backend:**
- ✅ Retell SDK integrated (`retell-sdk` in requirements.txt)
- ⚠️ `/trigger-call` endpoint currently uses `create_phone_call` (needs to change to `create_web_call`)
- ✅ Retell webhook handler (`/retell-webhook`) receives call events
- ✅ Transcript extraction from Retell call data (in `call_ended` event)
- ✅ Todo management API (`/todos` endpoints)
- ✅ OTP authentication (`/otp/send`, `/otp/verify`) - Note: Still uses phone for auth, but not for voice calls
- ✅ SQLite database for todos
- ✅ Redis for rate limiting

**iOS App:**
- ✅ Screen time monitoring with DeviceActivityMonitor
- ✅ Threshold detection in `UsageMonitorExtension`
- ✅ Todo list management with backend sync
- ✅ OTP-based authentication
- ✅ NetworkManager for API calls
- ✅ App Group for app-extension communication

### ❌ What Needs to Be Built

**Backend:**
- ❌ Web call creation endpoint (`/retell/create-web-call`) - Replace phone calls with web calls
- ❌ Transcript storage in database
- ❌ Transcript evaluation endpoint (`/evaluate-transcript`)
- ❌ Unblock decision API (`/unblock-status/{call_id}`)
- ❌ Call session management (link calls to users/apps)

**iOS App:**
- ❌ App blocking with `ManagedSettings.Shield`
- ❌ Block screen UI when user tries to open blocked app
- ❌ WebRTC integration for Retell web calls (Google WebRTC or Retell iOS SDK)
- ❌ Voice call UI and WebRTC connection handling
- ❌ Unblock mechanism after AI approval
- ❌ Transcript history view

## Revised Architecture

### Key Insight: Retell WebRTC Web Calls

Retell's Web Call API (Call API V2) provides:
- ✅ WebRTC infrastructure (no need to build signaling server)
- ✅ Real-time STT (Speech-to-Text) - handled by Retell
- ✅ Real-time TTS (Text-to-Speech) - handled by Retell
- ✅ AI agent conversation management
- ✅ Call session management
- ✅ **No phone numbers required** - pure WebRTC in-app interaction

**Important:** Retell uses WebRTC for web calls, so we need:
1. Backend to create web call sessions (not phone calls)
2. iOS app to connect via WebRTC (using Google WebRTC or Retell's iOS SDK if available)
3. WebRTC connection between iOS app and Retell's servers

## Updated Implementation Flow (WebRTC Web Calls)

```
1. Threshold Reached
   ↓
2. UsageMonitorExtension.eventDidReachThreshold()
   ↓
3. Apply ManagedSettings.Shield (block selected apps)
   ↓
4. Store blocked state in App Group UserDefaults
   ↓
5. User tries to open blocked app
   ↓
6. System shows block screen → User taps "Talk to AI"
   ↓
7. iOS app opens → VoiceCallView
   ↓
8. iOS app calls backend: POST /retell/create-web-call
   ↓
9. Backend creates Retell web call session (returns access_token + connection details)
   ↓
10. iOS app connects via WebRTC using access_token → AI agent receives call
   ↓
11. Conversation happens (AI has access to todos via Retell dynamic variables)
   ↓
12. Call ends → Retell webhook fires → Backend saves transcript
   ↓
13. Backend evaluates transcript via LLM
   ↓
14. Backend stores decision → iOS polls /retell/unblock-status/{call_id}
   ↓
15. If approved → iOS removes ManagedSettings shield
```

**Key Difference:** No phone numbers involved in the voice interaction - pure WebRTC connection from iOS app to Retell's servers.

## Detailed Implementation Plan

### Phase 1: App Blocking Infrastructure ⚠️ CRITICAL

**Goal:** Block apps when threshold is reached

**iOS Changes:**

1. **Modify `UsageMonitorExtension.swift`**
   - Import `ManagedSettings` framework
   - Add `ApplicationToken` storage for blocked apps
   - On `eventDidReachThreshold()`:
     - Read selected apps from App Group
     - Apply `ManagedSettings.Shield` to block them
     - Store blocked state in UserDefaults
   - Track which apps are currently blocked

2. **Create `BlockManager.swift`**
   ```swift
   import ManagedSettings
   
   class BlockManager {
       static let shared = BlockManager()
       private let shield = ShieldManager()
       
       func blockApps(_ tokens: Set<ApplicationToken>) {
           // Apply shield
       }
       
       func unblockApps() {
           // Remove shield
       }
   }
   ```

3. **Update `Shared.swift`**
   - Add keys: `blockedApps`, `isBlocked`, `blockedAt`

**Backend Changes:**
- None required for Phase 1

**Testing:**
- Test on physical device (ManagedSettings requires real device)
- Verify apps are blocked when threshold reached
- Verify block persists across app restarts

---

### Phase 2: Block Screen UI

**Goal:** Show UI when user tries to open blocked app

**iOS Changes:**

1. **Create `BlockScreenView.swift`**
   - Full-screen view with app icon/name
   - Message: "This app is blocked. Talk to AI to unblock?"
   - Button: "Talk to AI Agent"
   - Navigate to `VoiceCallView` on tap

2. **Create `BlockScreenManager.swift`**
   - Monitor for blocked app launch attempts
   - Present `BlockScreenView` when detected
   - Use URL scheme or deep linking

**Note:** Apple's `ManagedSettings` doesn't provide a direct way to intercept app launches. We may need to:
- Use a custom URL scheme
- Show block screen as overlay when app is detected as blocked
- Or rely on user manually opening our app

**Alternative Approach:** Instead of intercepting launches, show a persistent notification/banner when apps are blocked, directing users to our app.

**Backend Changes:**
- None required

---

### Phase 3: WebRTC Web Call Integration

**Goal:** Enable WebRTC-based voice calls with AI agent (no phone numbers)

**iOS Changes:**

1. **Add WebRTC Framework**
   - Option A: Google WebRTC for iOS (via CocoaPods or SPM)
     - `pod 'GoogleWebRTC'` or Swift Package: `https://github.com/webrtc-sdk/Specs.git`
   - Option B: Retell iOS SDK (if available - check Retell docs)
   - We'll use Google WebRTC as it's the most reliable option

2. **Create `WebRTCManager.swift`**
   ```swift
   import WebRTC
   
   class WebRTCManager {
       private var peerConnection: RTCPeerConnection?
       private var audioTrack: RTCAudioTrack?
       
       func connectToRetell(accessToken: String, completion: @escaping (Bool) -> Void) {
           // Initialize WebRTC peer connection
           // Connect to Retell's WebRTC endpoint using access_token
           // Handle ICE candidates, SDP exchange
           // Set up audio tracks for microphone input
       }
       
       func startAudio() {
           // Enable microphone, start audio capture
       }
       
       func endCall() {
           // Close peer connection, cleanup
       }
   }
   ```

3. **Create `RetellCallManager.swift`**
   ```swift
   class RetellCallManager {
       private let webRTCManager = WebRTCManager()
       
       func startCall(todos: [Todo], blockedApp: String, completion: @escaping (String?) -> Void) {
           // 1. Call backend to create web call session
           // 2. Get access_token and connection details
           // 3. Use WebRTCManager to connect
           // 4. Handle call events
       }
   }
   ```

4. **Create `VoiceCallView.swift`**
   - Call UI (mute, hang up, speaker toggle)
   - Show call status (connecting, active, ended)
   - Display real-time transcript (if Retell provides via WebSocket)
   - Handle call end → navigate to decision screen
   - Request microphone permission

5. **Update `NetworkManager.swift`**
   - Add `createWebCall(todos:blockedApp:completion:)` method
   - Calls `POST /retell/create-web-call`
   - Returns: `{ access_token: String, call_id: String, ... }`

**Backend Changes:**

1. **Update `/trigger-call` endpoint → Create `/retell/create-web-call`**
   ```python
   @app.post("/retell/create-web-call")
   async def create_web_call(payload: dict):
       """
       Create a Retell web call session (WebRTC, no phone number needed).
       Returns access_token for iOS app to connect via WebRTC.
       """
       user_phone = payload.get("phone")  # For user identification only
       todos = payload.get("todos", [])
       blocked_app = payload.get("blocked_app", "")
       minutes = payload.get("minutes", 0)
       
       task_list_str = "\n".join([f"• {todo['task']}" for todo in todos])
       
       # Create web call (not phone call!)
       call = await client.call.create_web_call(
           retell_llm_dynamic_variables={
               "todos": task_list_str,
               "minutes": str(minutes),
               "blocked_app": blocked_app,
               "goal": "Help user pause doomscrolling and reset"
           },
           # Optional: user_id for tracking
           user_id=user_phone
       )
       
       return {
           "call_id": call.call_id,
           "access_token": call.access_token,  # For WebRTC connection
           "connection_url": call.connection_url  # WebRTC endpoint
       }
   ```

2. **Update Retell webhook handler**
   - Store full transcript in database
   - Link transcript to user (by phone/user_id) and blocked app
   - Trigger evaluation automatically

3. **Add call status endpoint**
   ```python
   @app.get("/retell/unblock-status/{call_id}")
   async def get_unblock_status(call_id: str):
       # Get transcript by call_id
       # Return decision if available
       # Return: { "decision": bool, "reason": str, "status": "pending"|"completed" }
   ```

**Testing:**
- Test WebRTC connection from iOS app
- Verify audio quality (mic input, speaker output)
- Test call end handling
- Verify transcript is received via webhook
- Test on physical device (WebRTC requires real device)

---

### Phase 4: Transcript Storage & Evaluation

**Goal:** Save transcripts and evaluate for unblock approval

**Backend Changes:**

1. **Create `Transcript` model in `models.py`**
   ```python
   class Transcript(Base):
       __tablename__ = "transcripts"
       
       id = Column(Integer, primary_key=True)
       user_phone = Column(String, index=True)
       call_id = Column(String, unique=True)
       transcript = Column(Text)
       app_blocked = Column(String)
       todos_at_time = Column(Text)  # JSON
       decision = Column(Boolean, nullable=True)
       decision_reason = Column(Text)
       created_at = Column(DateTime)
   ```

2. **Update `db.py`**
   - Import Transcript model
   - Ensure table creation

3. **Update `/retell-webhook` endpoint**
   - On `call_ended`: Save transcript to database
   - Extract todos, app blocked, user phone from call metadata
   - Trigger evaluation (or queue for async processing)

4. **Create `/evaluate-transcript` endpoint**
   ```python
   @app.post("/evaluate-transcript")
   async def evaluate_transcript(transcript_id: int):
       # Load transcript from DB
       # Call LLM (OpenAI/Anthropic) with prompt:
       #   - User's todos
       #   - Time spent on app
       #   - Conversation transcript
       #   - Evaluation criteria
       # Save decision to DB
       # Return decision
   ```

5. **Create `evaluation.py`**
   ```python
   async def evaluate_conversation(transcript: str, todos: List[str], minutes: int) -> dict:
       # LLM prompt engineering
       # Return: {"approved": bool, "reason": str}
   ```

**LLM Evaluation Criteria:**
- Did user mention completing todos?
- Valid reason (work, emergency, etc.)?
- Shows awareness of time limit?
- Not just making excuses?

**iOS Changes:**

1. **Create `TranscriptModel.swift`**
   ```swift
   struct Transcript: Codable, Identifiable {
       let id: Int
       let callId: String
       let transcript: String
       let appBlocked: String
       let decision: Bool?
       let decisionReason: String?
       let createdAt: Date
   }
   ```

2. **Update `NetworkManager.swift`**
   - Add `checkUnblockStatus(callId:completion:)` method
   - Polls backend for decision after call ends

**Testing:**
- Test transcript saving
- Test LLM evaluation with various scenarios
- Test decision accuracy

---

### Phase 5: Unblock Mechanism

**Goal:** Remove app blocks when AI approves

**iOS Changes:**

1. **Update `BlockManager.swift`**
   - Add `unblockApps()` method
   - Remove `ManagedSettings.Shield`
   - Update UserDefaults state

2. **Update `VoiceCallView.swift`**
   - After call ends, poll backend for decision
   - Show decision screen (approved/rejected)
   - If approved: Call `BlockManager.unblockApps()`
   - If rejected: Show reason, keep apps blocked

3. **Create `DecisionView.swift`**
   - Show transcript summary
   - Show AI decision and reason
   - Button to retry call if rejected

**Backend Changes:**

1. **Create `/unblock-status/{call_id}` endpoint**
   ```python
   @app.get("/unblock-status/{call_id}")
   async def get_unblock_status(call_id: str):
       # Get transcript by call_id
       # Return decision if available
   ```

2. **Optional: Add WebSocket/SSE for real-time updates**
   - Push decision to iOS app when ready
   - Avoids polling

**Testing:**
- Test unblock flow end-to-end
- Verify apps become accessible after approval
- Test rejection flow

---

### Phase 6: Polish & Edge Cases

**Goal:** Handle edge cases and improve UX

**iOS Changes:**

1. **Error Handling**
   - Network failures during call
   - Retell SDK connection failures
   - Backend unavailability

2. **Retry Logic**
   - Retry failed calls
   - Exponential backoff

3. **Transcript History**
   - Create `TranscriptHistoryView.swift`
   - Show past conversations
   - Display decisions and reasons

4. **Settings**
   - Allow manual override (with confirmation)
   - Adjust evaluation strictness
   - View/edit blocked apps

**Backend Changes:**

1. **Error Handling**
   - Handle Retell API failures
   - Graceful degradation

2. **Rate Limiting**
   - Limit unblock requests per hour
   - Prevent abuse

3. **Analytics**
   - Track approval/rejection rates
   - Monitor call quality

---

## Technical Stack Summary

| Component | Technology | Status |
|-----------|-----------|--------|
| **Voice AI** | Retell SDK | ✅ Already integrated |
| **WebRTC** | Google WebRTC (iOS) + Retell Web Call API | ❌ Needs iOS integration |
| **STT/TTS** | Retell SDK (handled internally) | ✅ No setup needed |
| **Backend Framework** | FastAPI | ✅ Already set up |
| **Database** | SQLite | ✅ Already set up |
| **Authentication** | JWT + OTP | ✅ Already set up (phone for auth only, not for calls) |
| **App Blocking** | ManagedSettings | ❌ Needs implementation |
| **LLM Evaluation** | OpenAI/Anthropic | ❌ Needs integration |

## Key Differences from Original Plan

1. **✅ No Custom WebRTC Signaling Server Needed**
   - Retell handles signaling internally
   - Backend just creates web call sessions
   - iOS connects directly to Retell via WebRTC

2. **✅ No STT/TTS Setup Needed**
   - Retell provides real-time transcription
   - AI agent handles TTS automatically

3. **✅ No Phone Numbers for Voice Calls**
   - Users interact via WebRTC in-app
   - Phone number only used for authentication (OTP)
   - Much better UX - no need to answer phone calls

4. **⚠️ Need WebRTC Integration on iOS**
   - Must integrate Google WebRTC framework
   - Handle peer connection, audio tracks, ICE candidates
   - More complex than phone calls, but better UX

5. **⚠️ Still Need ManagedSettings**
   - App blocking still requires iOS implementation
   - This is the most critical missing piece

6. **⚠️ Still Need LLM Integration**
   - For transcript evaluation
   - Can use OpenAI API or Anthropic Claude

## Critical Path Items

1. **ManagedSettings Implementation** (Phase 1)
   - Most complex iOS change
   - Requires physical device testing
   - Apple approval considerations

2. **WebRTC Integration** (Phase 3)
   - Need to integrate Google WebRTC framework
   - Handle WebRTC connection to Retell's servers
   - Audio capture/playback setup
   - Requires physical device testing

3. **Backend Web Call API** (Phase 3)
   - Update backend to use `create_web_call` instead of `create_phone_call`
   - Return access_token and connection details
   - Verify Retell SDK supports web calls

4. **LLM Evaluation** (Phase 4)
   - Need to choose provider (OpenAI/Anthropic)
   - Prompt engineering critical for accuracy

## Questions to Resolve

1. **Retell Web Call API Details**
   - Verify `create_web_call` method exists in Retell SDK
   - Check API documentation: https://docs.retellai.com/
   - Confirm access_token format and WebRTC connection process
   - Check if Retell provides iOS SDK or we use Google WebRTC directly

2. **WebRTC Connection Details**
   - What's the WebRTC endpoint URL from Retell?
   - How to authenticate WebRTC connection with access_token?
   - Does Retell use standard WebRTC or custom protocol?

3. **ManagedSettings Limitations**
   - Can we intercept app launches?
   - Or rely on user manually opening our app?
   - Need to test on device

4. **Evaluation Criteria**
   - How strict should approval be?
   - Should we allow manual override?
   - User-configurable strictness?

5. **Audio Permissions**
   - Request microphone permission in iOS
   - Handle permission denial gracefully
   - Test audio routing (speaker vs earpiece)

## Next Steps

1. **Research Retell Web Call API**
   - Check Retell documentation: https://docs.retellai.com/
   - Verify `create_web_call` method in Python SDK
   - Understand WebRTC connection process
   - Check if Retell has iOS SDK or we use Google WebRTC

2. **Set Up WebRTC on iOS**
   - Add Google WebRTC framework (CocoaPods or SPM)
   - Create basic WebRTC connection test
   - Test connection to Retell's WebRTC endpoint

3. **Start Phase 1 Implementation**
   - Implement ManagedSettings blocking
   - Test on physical device

4. **Update Backend for Web Calls**
   - Replace `create_phone_call` with `create_web_call`
   - Test web call creation
   - Verify access_token generation

5. **Set Up LLM Provider**
   - Choose OpenAI or Anthropic
   - Set up API keys
   - Create evaluation prompt

6. **Design Block Screen UX**
   - How to intercept app launches?
   - Fallback if interception not possible

---

**Last Updated:** After backend review
**Status:** Ready for implementation - Plan updated with Retell integration insights
