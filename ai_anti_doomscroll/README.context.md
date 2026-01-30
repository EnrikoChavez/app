# AI Anti-Doomscroll - Project Context

## Project Overview

An iOS app that helps users combat doomscrolling by monitoring screen time usage and implementing interventions when users exceed time limits on distracting apps.

## Current Implementation (As of Conversation)

### Core Features
1. **Screen Time Monitoring**: Uses Apple's `FamilyControls` and `DeviceActivity` APIs to monitor app usage
2. **Threshold-Based Triggers**: Configures multiple thresholds (1x, 2x, 3x, 4x base minutes) for progressive monitoring
3. **Todo List Management**: Users can create and manage a todo list that syncs with a backend API
4. **Phone-Based Authentication**: OTP-based login system using phone numbers
5. **Backend Integration**: When thresholds are reached, triggers a backend API call (currently sends phone number, minutes, and todos)

### Architecture
- **Main App**: SwiftUI app with modular components
- **UsageMonitorExtension**: DeviceActivityMonitor extension that runs in background
- **App Group**: Shared UserDefaults for communication between app and extension
- **NetworkManager**: Handles all API calls to backend
- **KeychainHelper**: Secure token storage for authentication

### Current Flow
```
User exceeds threshold → Extension detects → Sends POST to /trigger-call endpoint
```

## Planned Feature: AI Voice Agent Unblock System

### New Flow (To Be Implemented)

Instead of triggering a phone call, the app will:
1. **Block the distracting app** when threshold is reached
2. **Show a block screen** when user tries to open blocked app
3. **Require voice call to AI agent** to unblock (via WebRTC)
4. **AI agent has access to todo list** during conversation
5. **Transcribe the conversation** and save transcript
6. **AI evaluates transcript** to determine if user provided valid reason
7. **Unblock app** if AI approves

### Detailed Flow
```
1. Threshold Reached
   ↓
2. UsageMonitorExtension.eventDidReachThreshold()
   ↓
3. Apply ManagedSettings.Shield (block apps)
   ↓
4. User tries to open blocked app
   ↓
5. System shows block screen → User taps "Talk to AI"
   ↓
6. Your app opens → VoiceCallView
   ↓
7. WebRTC connects → AI agent receives call
   ↓
8. Conversation happens (AI has access to todos)
   ↓
9. Transcript saved (local + backend)
   ↓
10. Backend evaluates transcript via LLM
   ↓
11. Decision sent to app
   ↓
12. If approved → Remove ManagedSettings shield
```

## Technical Architecture

### Components to Build/Modify

#### 1. App Blocking (`ManagedSettings`)
- **File**: `UsageMonitorExtension.swift`
- **Changes**: 
  - Import `ManagedSettings` framework
  - On threshold reached: Apply shield to block selected apps
  - Store blocked state in App Group UserDefaults
  - Track which apps are currently blocked

#### 2. Block Screen UI
- **New File**: `BlockScreenView.swift`
- **Purpose**: 
  - Show when user tries to open blocked app
  - Single action: "Talk to AI Agent to Unblock"
  - Navigate to voice call interface

#### 3. WebRTC Voice Call Integration
- **New Files**: 
  - `VoiceCallView.swift` - WebRTC call interface
  - `WebRTCManager.swift` - WebRTC connection management
- **Requirements**:
  - Connect to backend WebRTC signaling server
  - Real-time audio streaming
  - Call UI (mute, hang up, etc.)
- **Backend**: WebRTC signaling server + AI voice agent integration

#### 4. Transcript Storage
- **New File**: `TranscriptModel.swift`
- **Data Model**: 
  ```swift
  struct ConversationTranscript {
      let id: UUID
      let timestamp: Date
      let transcript: String
      let decision: Bool // approved/rejected
      let appBlocked: String
      let todosAtTime: [Todo]
  }
  ```
- **Storage**: App Group UserDefaults or backend API

#### 5. AI Evaluation Service
- **Backend Endpoint**: `/evaluate-transcript`
- **Input**: transcript, todos, context
- **Output**: `{ approved: Bool, reason: String }`
- **Implementation**: LLM (OpenAI GPT-4, Anthropic Claude, etc.) with prompt engineering

#### 6. Unblock Mechanism
- **New File**: `UnblockManager.swift`
- **Function**: `unblockApp()`
- **Action**: Remove `ManagedSettings` shield
- **Update**: Blocked state in UserDefaults

### Technical Stack Recommendations

| Component | Recommendation | Notes |
|-----------|---------------|-------|
| **WebRTC** | Google WebRTC (iOS) or Twilio Voice SDK | Real-time audio streaming |
| **Voice AI** | Deepgram (real-time STT/TTS) or AssemblyAI | Speech-to-text and text-to-speech |
| **Backend Signaling** | Node.js/WebSocket server or Twilio | WebRTC signaling server |
| **AI Evaluation** | OpenAI GPT-4 or Anthropic Claude | Transcript evaluation |
| **Audio Recording** | AVAudioEngine + WebRTC | Local audio handling |

## Key Challenges & Considerations

### 1. ManagedSettings Limitations
- **Issue**: Shields can be bypassed with Screen Time passcode
- **Mitigation**: Require Screen Time passcode, use strict mode
- **Note**: Apple may impose restrictions on custom blocking UI

### 2. WebRTC Complexity
- **Challenges**: 
  - Signaling server setup
  - Audio routing (speaker/earpiece)
  - Background handling
  - Network reliability
- **Solutions**: Use established SDKs (Twilio), implement CallKit for proper VoIP behavior

### 3. AI Evaluation Criteria
- **Need**: Clear, consistent criteria for approval
- **Considerations**:
  - User completed todos?
  - Valid reason (urgency, work-related)?
  - Time since last override?
  - User awareness (mentions specific time limit)?
- **Risk**: Too strict = frustrating UX, too lenient = defeats purpose

### 4. Privacy & Permissions
- **Requirements**:
  - Explicit consent for audio recording
  - Transparent about transcript storage
  - Encrypt data in transit and at rest
  - Allow users to view past transcripts

### 5. UX Considerations
- **Latency**: Minimize delay between call end and decision
- **Feedback**: Show partial transcripts, clear approval/rejection reasons
- **Fallback**: Allow appeal or manual override if AI wrongly blocks

## Implementation Plan

### Phase 1: App Blocking
1. Implement `ManagedSettings` shield application
2. Modify `UsageMonitorExtension` to block apps on threshold
3. Create `BlockScreenView` UI
4. Test blocking/unblocking flow

### Phase 2: WebRTC Infrastructure
1. Set up WebRTC SDK (Google WebRTC or Twilio)
2. Create `WebRTCManager` for connection handling
3. Build `VoiceCallView` UI
4. Set up backend signaling server
5. Integrate AI voice agent (STT/TTS)

### Phase 3: Transcript & Evaluation
1. Create `TranscriptModel` data structure
2. Implement transcript saving (local + backend)
3. Build backend `/evaluate-transcript` endpoint
4. Integrate LLM for evaluation
5. Test evaluation logic

### Phase 4: Unblock Mechanism
1. Create `UnblockManager` to handle shield removal
2. Implement approval flow
3. Add UI feedback for approval/rejection
4. Test end-to-end flow

### Phase 5: Polish & Edge Cases
1. Handle network failures gracefully
2. Add retry logic for failed calls
3. Implement transcript history view
4. Add user settings for evaluation criteria
5. Privacy compliance and consent flows

## Current Codebase Notes

### Files Structure
```
ai_anti_doomscroll/
├── ai_anti_doomscrollApp.swift      # Main app entry, login state
├── ContentView.swift                 # Main UI, todo + screen time sections
├── ScreenTimeSection.swift           # Screen time monitoring UI
├── TodoSection.swift                 # Todo list UI
├── LoginView.swift                   # Phone OTP authentication
├── NetworkManager.swift              # API calls to backend
├── APIConfig.swift                   # Base URL configuration
├── KeychainHelper.swift              # Secure token storage
├── Shared.swift                      # App Group, shared UserDefaults
└── LogoutButton.swift                # Logout functionality

UsageMonitorExtension/
└── UsageMonitorExtension.swift       # DeviceActivityMonitor implementation
```

### Known Issues (To Fix Later)
1. **Code Duplication**: `Todo` struct defined in both `ContentView.swift` and `UsageMonitorExtension.swift` - should be in shared file
2. **Inconsistent Storage**: Phone number stored in both `UserDefaults.standard` and `Shared.defaults` - standardize on App Group
3. **Incomplete Logout**: `logout()` doesn't clear Keychain token
4. **Error Handling**: Network calls lack robust error handling
5. **Hardcoded URLs**: `APIConfig.baseURL` sets hardcoded localhost URL

### App Group Configuration
- **App Group ID**: `group.OrgIdentifier.ai-anti-doomscroll`
- **Shared Keys**:
  - `fc.selection` - FamilyControls selection
  - `fc.minutes` - Threshold minutes
  - `userPhone` - User's phone number
  - `baseURL` - Backend base URL
  - `todos_json` - Todo list JSON

## Backend API Endpoints (Current)

### Authentication
- `POST /otp/send` - Send OTP to phone number
- `POST /otp/verify` - Verify OTP and get token

### Todos
- `GET /todos` - Fetch user's todos
- `POST /todos` - Add new todo
- `DELETE /todos/{id}` - Delete todo

### Monitoring
- `POST /trigger-call` - Trigger phone call (current implementation)
  - Body: `{ phone, minutes, todos }`

## Backend API Endpoints (Planned)

### Voice Call
- `POST /webrtc/create-session` - Create WebRTC session
- `POST /webrtc/end-call` - End call and get transcript
- `POST /evaluate-transcript` - Evaluate transcript for unblock approval
  - Body: `{ transcript, todos, appBlocked, context }`
  - Response: `{ approved: Bool, reason: String }`

### Transcripts
- `GET /transcripts` - Get user's transcript history
- `GET /transcripts/{id}` - Get specific transcript

## Development Notes

### Testing Considerations
- Test on physical device (FamilyControls not available in simulator)
- Test with various network conditions
- Test WebRTC with poor connectivity
- Test AI evaluation with various conversation scenarios
- Test unblock flow with multiple apps

### Privacy & Compliance
- Get explicit user consent for audio recording
- Inform users about transcript storage
- Provide way to delete transcripts
- Comply with App Store guidelines
- Consider GDPR/CCPA requirements

### Future Enhancements (Post-MVP)
- Multiple AI agents (different personalities)
- Custom evaluation criteria per user
- Analytics dashboard (usage patterns, success rates)
- Social features (accountability partners)
- Gamification (streaks, achievements)

---

**Last Updated**: Conversation date
**Status**: Planning phase - Feature not yet implemented
