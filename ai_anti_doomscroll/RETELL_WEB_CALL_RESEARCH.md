# Retell Web Call API Research - Step 1

**Date:** Research completed  
**Status:** ✅ Ready for implementation

## Executive Summary

Retell SDK **does support WebRTC web calls** via the `create_web_call` method. This allows in-app voice interactions without requiring phone numbers. The backend can create web call sessions that return connection details for iOS to connect via WebRTC.

---

## Key Findings

### ✅ Retell Python SDK Methods

**Available Methods in `client.call`:**
- ✅ `create_web_call` - **This is what we need!**
- ✅ `create_phone_call` - Currently used, needs to be replaced
- ✅ `retrieve` - Get call details
- ✅ `list` - List calls
- ✅ `delete` - Delete call
- ✅ `update` - Update call

### ✅ `create_web_call` Method Signature

```python
create_web_call(
    *,
    agent_id: str,  # REQUIRED - Retell agent ID
    agent_version: int | NotGiven = NOT_GIVEN,
    metadata: object | NotGiven = NOT_GIVEN,
    retell_llm_dynamic_variables: Dict[str, object] | NotGiven = NOT_GIVEN,
    extra_headers: Headers | None = None,
    extra_query: Query | None = None,
    extra_body: Body | None = None,
    timeout: float | httpx.Timeout | None | NotGiven = NOT_GIVEN
) -> WebCallResponse
```

### ✅ Required Parameters

1. **`agent_id`** (required)
   - The Retell agent ID to use for the call
   - Must be configured in Retell dashboard
   - This is the AI agent that will handle the conversation

2. **`retell_llm_dynamic_variables`** (optional but needed)
   - Dictionary of variables to pass to the AI agent
   - Can include: `todos`, `minutes`, `blocked_app`, `goal`, etc.
   - These variables are available to the AI during the conversation

### ✅ Response Structure

The method returns a `WebCallResponse` object which likely contains:
- `call_id` - Unique identifier for the call
- `access_token` - Token for WebRTC connection (needed by iOS)
- `connection_url` or similar - WebRTC endpoint URL
- Other metadata

**Note:** Need to verify exact response structure by testing or checking Retell docs.

---

## Backend Implementation Plan

### Current State

**File:** `backend/main.py`

**Current endpoint:**
```python
@app.post("/trigger-call")
async def trigger_call(payload: dict):
    call = await client.call.create_phone_call(
        from_number=os.getenv("CALLER_NUMBER"),
        to_number=payload["phone"],
        retell_llm_dynamic_variables={...}
    )
    return {"callId": call.call_id}
```

**Issues:**
- Uses `create_phone_call` (requires phone numbers)
- Returns only `call_id` (not enough for WebRTC)

### New Implementation

**New endpoint to create:**
```python
@app.post("/retell/create-web-call")
async def create_web_call(payload: dict):
    """
    Create a Retell web call session (WebRTC, no phone number needed).
    Returns access_token for iOS app to connect via WebRTC.
    """
    # Extract data from payload
    user_phone = payload.get("phone")  # For user identification only
    todos = payload.get("todos", [])
    blocked_app = payload.get("blocked_app", "")
    minutes = payload.get("minutes", 0)
    
    # Format todos for AI agent
    task_list_str = "\n".join([f"• {todo['task']}" for todo in todos])
    
    # Get agent_id from environment (or config)
    agent_id = os.getenv("RETELL_AGENT_ID")  # Need to set this!
    
    # Create web call (not phone call!)
    call = await client.call.create_web_call(
        agent_id=agent_id,
        retell_llm_dynamic_variables={
            "todos": task_list_str,
            "minutes": str(minutes),
            "blocked_app": blocked_app,
            "goal": "Help user pause doomscrolling and reset"
        },
        metadata={
            "user_phone": user_phone,
            "blocked_app": blocked_app
        }
    )
    
    # Return connection details for iOS
    return {
        "call_id": call.call_id,
        "access_token": call.access_token,  # For WebRTC connection
        # May also need: connection_url, websocket_url, etc.
    }
```

### Environment Variables Needed

Add to `.env`:
```bash
RETELL_AGENT_ID=your_agent_id_here
```

**How to get agent_id:**
1. Log into Retell dashboard
2. Create or select an AI agent
3. Copy the agent ID from agent settings

---

## iOS WebRTC Integration

### What We Know

1. **Retell provides Web SDK** (`retell-client-js-sdk`) for web browsers
2. **For iOS native apps**, we likely need to:
   - Use Google WebRTC framework
   - Connect to Retell's WebRTC endpoint using `access_token`
   - Handle peer connection, audio tracks, ICE candidates

### Questions to Resolve

1. **Does Retell have an iOS SDK?**
   - Check: https://docs.retellai.com/
   - If yes, use it
   - If no, use Google WebRTC + Retell's WebRTC endpoint

2. **WebRTC Connection Process:**
   - How to authenticate with `access_token`?
   - What's the WebRTC endpoint URL?
   - Does Retell use standard WebRTC or custom protocol?

3. **Response Structure:**
   - What exactly does `WebCallResponse` contain?
   - Need to test or check Retell docs

### iOS Implementation Approach

**Option A: Use Retell iOS SDK (if available)**
```swift
import RetellSDK

let call = RetellCall(accessToken: accessToken)
call.start()
```

**Option B: Use Google WebRTC (if no iOS SDK)**
```swift
import WebRTC

// Initialize peer connection
// Connect to Retell's WebRTC endpoint
// Handle audio tracks
```

---

## Testing Plan

### Backend Testing

1. **Test `create_web_call` method:**
   ```python
   # Test script
   call = await client.call.create_web_call(
       agent_id="test_agent_id",
       retell_llm_dynamic_variables={"test": "value"}
   )
   print(call.call_id)
   print(call.access_token)  # Verify this exists
   print(dir(call))  # See all available attributes
   ```

2. **Verify response structure:**
   - Check what attributes `WebCallResponse` has
   - Document exact response format

3. **Test endpoint:**
   - Call `/retell/create-web-call` with test payload
   - Verify response contains `access_token` and `call_id`

### iOS Testing

1. **Test WebRTC connection:**
   - Use `access_token` from backend
   - Connect to Retell's WebRTC endpoint
   - Verify audio works (mic input, speaker output)

2. **Test end-to-end:**
   - Create web call from iOS
   - Have conversation with AI
   - Verify transcript is received

---

## Next Steps

### Immediate Actions

1. ✅ **Research complete** - `create_web_call` exists and is usable
2. ⏭️ **Get Retell Agent ID**
   - Log into Retell dashboard
   - Create/configure AI agent
   - Copy agent ID to `.env`

3. ⏭️ **Test `create_web_call` in backend**
   - Create test script
   - Verify response structure
   - Document exact response format

4. ⏭️ **Update backend endpoint**
   - Replace `/trigger-call` with `/retell/create-web-call`
   - Return `access_token` and connection details
   - Test endpoint

5. ⏭️ **Research iOS WebRTC integration**
   - Check if Retell has iOS SDK
   - If not, plan Google WebRTC integration
   - Understand connection process

### Documentation to Check

- Retell API Docs: https://docs.retellai.com/
- Retell Web Call Guide: https://docs.retellai.com/deploy/web-call
- Retell Migration Guide: https://docs.retellai.com/api-references/migration-doc

---

## Key Differences: Phone Calls vs Web Calls

| Aspect | Phone Calls (`create_phone_call`) | Web Calls (`create_web_call`) |
|--------|-----------------------------------|-------------------------------|
| **Phone Number** | Required (`from_number`, `to_number`) | Not required |
| **Connection** | PSTN/SIP (phone network) | WebRTC (internet) |
| **User Experience** | User receives phone call | User connects in-app |
| **Response** | `call_id` only | `call_id` + `access_token` + connection details |
| **Use Case** | Outbound calls to phone | In-app voice interaction |

---

## Risks & Considerations

1. **Agent ID Required**
   - Must configure Retell agent before using
   - Agent defines AI behavior and prompts

2. **WebRTC Complexity**
   - More complex than phone calls
   - Requires WebRTC framework on iOS
   - Network/connectivity issues

3. **Response Structure Unknown**
   - Need to verify exact response format
   - May need to adjust based on actual response

4. **iOS SDK Availability**
   - Unknown if Retell provides native iOS SDK
   - May need to use Google WebRTC directly

---

## Summary

✅ **Confirmed:** Retell SDK supports web calls via `create_web_call`  
✅ **Confirmed:** Method signature and parameters understood  
⏭️ **Next:** Test actual response structure and get agent ID  
⏭️ **Next:** Research iOS WebRTC integration approach  

**Status:** Ready to proceed with backend implementation once agent ID is obtained.
