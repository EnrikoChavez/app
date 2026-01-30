# Implementation Summary - AI Anti-Doomscroll

**Last Updated:** After Step 1 Research  
**Status:** Ready for implementation

---

## 🎯 Project Goal

Build an iOS app that blocks distracting apps when users exceed screen time limits, requiring them to have a voice conversation with an AI agent (via WebRTC) to unblock. The AI evaluates the conversation and decides whether to approve unblocking.

**Key Requirement:** Use WebRTC for voice interaction (no phone numbers needed for calls).

---

## ✅ What's Already Built

### Backend (`/backend/`)
- ✅ FastAPI server running
- ✅ Retell SDK integrated (`retell-sdk` package)
- ✅ SQLite database for todos
- ✅ Redis for rate limiting
- ✅ OTP authentication (`/otp/send`, `/otp/verify`)
- ✅ Todo management API (`/todos` endpoints)
- ✅ Webhook handler (`/retell-webhook`) for call events
- ✅ Current `/trigger-call` endpoint (uses `create_phone_call` - needs updating)

### iOS App (`/ai_anti_doomscroll/`)
- ✅ Screen time monitoring with `DeviceActivityMonitor`
- ✅ Threshold detection in `UsageMonitorExtension`
- ✅ Todo list UI and backend sync
- ✅ OTP-based login
- ✅ NetworkManager for API calls
- ✅ App Group for app-extension communication

---

## ❌ What Needs to Be Built

### Phase 1: App Blocking Infrastructure (iOS)

**Goal:** Block apps when screen time threshold is reached

**Files to Create/Modify:**
1. **`BlockManager.swift`** (NEW)
   - Import `ManagedSettings` framework
   - Apply `ManagedSettings.Shield` to block selected apps
   - Remove shield to unblock apps
   - Track blocked state

2. **`UsageMonitorExtension.swift`** (MODIFY)
   - On threshold reached: Call `BlockManager` to block apps
   - Store blocked apps list in App Group UserDefaults
   - Track which apps are currently blocked

3. **`Shared.swift`** (MODIFY)
   - Add keys: `blockedApps`, `isBlocked`, `blockedAt`

**Requirements:**
- Add `ManagedSettings` framework import
- Add `FamilyControls` capability in Xcode
- Request Screen Time permissions from user
- Test on physical device (ManagedSettings requires real device)

---

### Phase 2: Block Screen UI (iOS)

**Goal:** Show UI when user tries to open blocked app

**Files to Create:**
1. **`BlockScreenView.swift`** (NEW)
   - Full-screen view showing blocked app info
   - Message: "This app is blocked. Talk to AI to unblock?"
   - Button: "Talk to AI Agent"
   - Navigate to `VoiceCallView` on tap

**Challenges:**
- Apple's `ManagedSettings` doesn't directly intercept app launches
- May need to show persistent notification/banner instead
- Or rely on user manually opening our app

---

### Phase 3: WebRTC Web Call Integration

**Goal:** Enable WebRTC-based voice calls with Retell AI agent

#### Backend Changes

**Files to Modify:**
1. **`main.py`** (MODIFY)
   - Replace `/trigger-call` endpoint OR create new `/retell/create-web-call`
   - Change from `create_phone_call` to `create_web_call`
   - Return `access_token` and connection details

**New Endpoint:**
```python
POST /retell/create-web-call
Request: {
    "phone": "user_phone",  # For identification only
    "todos": [...],
    "blocked_app": "app_name",
    "minutes": 15
}
Response: {
    "call_id": "...",
    "access_token": "...",  # For WebRTC connection
    "connection_url": "..."  # WebRTC endpoint
}
```

**Environment Variables Needed:**
- `RETELL_AGENT_ID` - Retell agent ID (get from Retell dashboard)

**Files to Create:**
2. **`models.py`** (MODIFY)
   - Add `Transcript` model for storing conversation transcripts
   - Fields: `id`, `user_phone`, `call_id`, `transcript`, `app_blocked`, `todos_at_time`, `decision`, `decision_reason`, `created_at`

3. **`main.py`** (MODIFY)
   - Update `/retell-webhook` to save transcripts to database
   - Link transcripts to users and blocked apps

#### iOS Changes

**Files to Create:**
1. **`WebRTCManager.swift`** (NEW)
   - Import Google WebRTC framework
   - Handle peer connection setup
   - Manage audio tracks (microphone input, speaker output)
   - Connect to Retell's WebRTC endpoint using `access_token`
   - Handle ICE candidates, SDP exchange

2. **`RetellCallManager.swift`** (NEW)
   - Coordinate between backend API and WebRTC
   - Call backend to create web call session
   - Use `WebRTCManager` to establish connection
   - Handle call events (connecting, active, ended)

3. **`VoiceCallView.swift`** (NEW)
   - Call UI (mute button, hang up button, speaker toggle)
   - Show call status (connecting, active, ended)
   - Display real-time transcript (if available)
   - Request microphone permission
   - Navigate to decision screen after call ends

**Files to Modify:**
4. **`NetworkManager.swift`** (MODIFY)
   - Add `createWebCall(todos:blockedApp:completion:)` method
   - Calls `POST /retell/create-web-call`
   - Returns connection details

**Dependencies to Add:**
- Google WebRTC framework (via CocoaPods or SPM)
- Or Retell iOS SDK (if available - need to verify)

---

### Phase 4: Transcript Storage & Evaluation

**Goal:** Save transcripts and evaluate for unblock approval

#### Backend Changes

**Files to Create/Modify:**
1. **`models.py`** (MODIFY)
   - Add `Transcript` model (see Phase 3)

2. **`main.py`** (MODIFY)
   - Update `/retell-webhook` handler:
     - On `call_ended`: Save full transcript to database
     - Link transcript to user (by phone/user_id) and blocked app
     - Trigger evaluation automatically

3. **`evaluation.py`** (NEW)
   - LLM integration (OpenAI or Anthropic)
   - Evaluation function: `evaluate_conversation(transcript, todos, minutes) -> dict`
   - Returns: `{"approved": bool, "reason": str}`
   - Evaluation criteria:
     - Did user mention completing todos?
     - Valid reason (work, emergency)?
     - Shows awareness of time limit?
     - Not just making excuses?

4. **`main.py`** (MODIFY)
   - Add `/evaluate-transcript` endpoint (optional - may be automatic)
   - Add `/retell/unblock-status/{call_id}` endpoint
     - Get transcript by call_id
     - Return decision if available
     - Response: `{"decision": bool, "reason": str, "status": "pending"|"completed"}`

**Dependencies to Add:**
- OpenAI SDK or Anthropic SDK
- Add to `requirements.txt`

#### iOS Changes

**Files to Create:**
1. **`TranscriptModel.swift`** (NEW)
   - Data model matching backend `Transcript`
   - Codable for JSON parsing

**Files to Modify:**
2. **`NetworkManager.swift`** (MODIFY)
   - Add `checkUnblockStatus(callId:completion:)` method
   - Polls `/retell/unblock-status/{call_id}` after call ends

---

### Phase 5: Unblock Mechanism

**Goal:** Remove app blocks when AI approves

#### iOS Changes

**Files to Modify:**
1. **`BlockManager.swift`** (MODIFY)
   - Add `unblockApps()` method
   - Remove `ManagedSettings.Shield`
   - Update UserDefaults state

2. **`VoiceCallView.swift`** (MODIFY)
   - After call ends, poll backend for decision
   - Show decision screen (approved/rejected)
   - If approved: Call `BlockManager.unblockApps()`
   - If rejected: Show reason, keep apps blocked

**Files to Create:**
3. **`DecisionView.swift`** (NEW)
   - Show transcript summary
   - Show AI decision and reason
   - Button to retry call if rejected

---

### Phase 6: Polish & Edge Cases

**Goal:** Handle edge cases and improve UX

#### iOS Changes
- Error handling (network failures, WebRTC connection failures)
- Retry logic for failed calls
- Transcript history view (`TranscriptHistoryView.swift`)
- Settings for manual override (with confirmation)
- View/edit blocked apps

#### Backend Changes
- Error handling for Retell API failures
- Rate limiting for unblock requests
- Analytics tracking (approval/rejection rates)

---

## 📋 Implementation Checklist

### Backend Tasks
- [ ] Get Retell Agent ID from dashboard
- [ ] Add `RETELL_AGENT_ID` to `.env`
- [ ] Create `/retell/create-web-call` endpoint
- [ ] Update to use `create_web_call` instead of `create_phone_call`
- [ ] Add `Transcript` model to `models.py`
- [ ] Update `/retell-webhook` to save transcripts
- [ ] Create `/retell/unblock-status/{call_id}` endpoint
- [ ] Add LLM provider (OpenAI/Anthropic) to `requirements.txt`
- [ ] Create `evaluation.py` for transcript evaluation
- [ ] Test web call creation
- [ ] Test transcript saving
- [ ] Test evaluation logic

### iOS Tasks
- [ ] Add `ManagedSettings` framework import
- [ ] Add `FamilyControls` capability in Xcode
- [ ] Request Screen Time permissions
- [ ] Create `BlockManager.swift`
- [ ] Modify `UsageMonitorExtension.swift` to block apps
- [ ] Create `BlockScreenView.swift`
- [ ] Add Google WebRTC framework (or Retell iOS SDK)
- [ ] Create `WebRTCManager.swift`
- [ ] Create `RetellCallManager.swift`
- [ ] Create `VoiceCallView.swift`
- [ ] Update `NetworkManager.swift` for web calls
- [ ] Create `TranscriptModel.swift`
- [ ] Create `DecisionView.swift`
- [ ] Implement unblock mechanism
- [ ] Add error handling
- [ ] Test on physical device

---

## 🔑 Key Technical Details

### Retell Web Call API
- **Method:** `client.call.create_web_call()`
- **Required:** `agent_id` (from Retell dashboard)
- **Optional:** `retell_llm_dynamic_variables` (todos, minutes, blocked_app, etc.)
- **Returns:** `WebCallResponse` with `call_id`, `access_token`, connection details

### WebRTC Connection
- iOS app receives `access_token` from backend
- Connects to Retell's WebRTC endpoint using `access_token`
- Uses Google WebRTC framework (or Retell iOS SDK if available)
- Handles audio capture (mic) and playback (speaker)

### App Blocking
- Uses `ManagedSettings.Shield` to block apps
- Requires `FamilyControls` capability
- Requires Screen Time permissions
- Must test on physical device

### Transcript Evaluation
- LLM evaluates conversation transcript
- Considers: todos completion, valid reasons, time awareness
- Returns approval/rejection with reason

---

## ⚠️ Critical Dependencies

1. **Retell Agent ID** - Must be obtained from Retell dashboard
2. **LLM Provider** - Need OpenAI or Anthropic API key
3. **Physical Device** - ManagedSettings requires real device testing
4. **WebRTC Framework** - Google WebRTC or Retell iOS SDK

---

## 📊 Estimated Timeline

| Phase | Estimated Time |
|-------|----------------|
| Phase 1: App Blocking | 2-3 days |
| Phase 2: Block Screen UI | 1-2 days |
| Phase 3: WebRTC Integration | 3-5 days |
| Phase 4: Transcript & Evaluation | 2-3 days |
| Phase 5: Unblock Mechanism | 1-2 days |
| Phase 6: Polish & Edge Cases | 2-3 days |
| **Total** | **11-18 days** |

---

## 🚀 Next Immediate Steps

1. Get Retell Agent ID from dashboard
2. Add `RETELL_AGENT_ID` to backend `.env`
3. Test `create_web_call` in backend to verify response structure
4. Start Phase 1: Implement app blocking with ManagedSettings
5. Research Retell iOS SDK availability (or plan Google WebRTC integration)

---

**Status:** Research complete, ready to begin implementation.
