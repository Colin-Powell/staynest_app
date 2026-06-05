# Real-Time Messaging & Calls - Audit Report

## Summary
✅ **Core Infrastructure**: 95% Complete
- Socket.IO backend server with message + WebRTC signaling
- REST API for message persistence + conversations
- Flutter services (Socket, Call, Message services)
- UI scaffolding for chat and calls

❌ **Critical Missing Pieces**: 40% Complete
- Incoming call notification system
- Call acceptance/rejection UI flow
- Remote stream rendering (viewer for remote video)
- Incoming message notifications
- Call state management (ringing, connecting, connected, ended)
- Error handling & reconnection logic

---

## BACKEND (95% Complete)

### ✅ Implemented

#### Socket.IO Server (`socket.ts`)
- **Authentication**: JWT-based socket connection with user rooms
- **Message Events**: `message` event saves to DB and broadcasts to recipient room
- **WebRTC Signaling**: `offer`, `answer`, `ice-candidate` events for peer connection
- **Routing**: Correct room-based targeting using `user:{userId}` rooms

#### REST API (`messages.ts`)
- `POST /messages` - Save message to DB
- `GET /messages/conversation/{userId}` - Fetch conversation history (paginated)
- `GET /messages/conversations` - Fetch all active conversations with last message

#### Database Schema (`init-db.sql`)
- `messages` table: `id`, `from_user_id`, `to_user_id`, `text`, `created_at`
- Indexes: On (from_user_id, to_user_id, created_at DESC) for efficient queries
- Foreign keys: Proper cascading deletes on user deletion

### ❌ Missing

1. **Call Lifecycle Table** - Track call history, duration, status
   ```sql
   CREATE TABLE calls (
     id uuid PRIMARY KEY,
     from_user_id uuid,
     to_user_id uuid,
     status text, -- initiated | ringing | accepted | rejected | ended
     started_at timestamptz,
     ended_at timestamptz,
     duration_seconds integer
   );
   ```

2. **Incoming Call Notification Event** - Socket event for incoming calls
   ```typescript
   socket.on('call-request', (data) => {
     io.to(`user:${data.to}`).emit('incoming-call', { 
       from: uid, 
       name, 
       avatar 
     });
   });
   ```

3. **Call Rejection/Acceptance Handlers**
   ```typescript
   socket.on('call-accepted', (data) => {
     io.to(`user:${data.to}`).emit('call-accepted');
   });
   socket.on('call-rejected', (data) => {
     io.to(`user:${data.to}`).emit('call-rejected', { reason });
   });
   socket.on('call-ended', (data) => {
     io.to(`user:${data.to}`).emit('call-ended');
   });
   ```

4. **Reconnection & Heartbeat** - Keep-alive mechanism for long-lived connections

5. **Error Broadcasting** - Standardized error event for socket failures

---

## FLUTTER FRONTEND (70% Complete)

### ✅ Implemented

#### SocketService (`services/socket_service.dart`)
- Socket connection with JWT auth
- Event handlers: `message`, `offer`, `answer`, `ice-candidate`
- Stream-based architecture for real-time updates
- Methods: `sendMessage()`, `sendOffer()`, `sendAnswer()`, `sendIce()`

#### MessageService (`services/message_service.dart`)
- REST API integration for message persistence
- Models: `MessageModel`, `ConversationModel`
- Methods: `saveMessage()`, `fetchConversation()`, `fetchConversations()`

#### CallService (`services/call_service.dart`)
- WebRTC peer connection setup with Google STUN servers
- Media stream acquisition (audio + video)
- Offer/Answer/ICE candidate handling
- Methods: `getLocalStream()`, `initializePeerConnection()`, `createOffer()`, `createAnswer()`, `addIceCandidate()`
- Callbacks: `onLocalIceCandidate`, `onRemoteStreamAdded`, `onConnectionStateChange`

#### ChatView UI (`screens/communication/chat_view.dart`)
- Message list with sender/receiver differentiation
- Text input with sending functionality
- Socket message listener
- REST API integration for persistence
- ✅ Animations and UX polish

#### CallingView UI (`screens/communication/calling_view.dart`)
- Entry animation
- Call timer
- Mute/speaker/video toggles
- Outgoing call initialization
- Socket signal listener (offer/answer/ice)
- ✅ Call controls UI

#### Main App Integration
- SocketService initialization on app start
- Signal listener setup
- Chat overlay management
- Call routing

### ❌ Missing - CRITICAL

1. **Incoming Call Handler** - No UI/logic to handle `incoming-call` socket event
   - [ ] Detect incoming offer from socket signal
   - [ ] Trigger incoming call notification
   - [ ] Show accept/reject dialog
   - [ ] Handle user response

2. **Incoming Call UI** - No widget for displaying incoming call with accept/reject buttons
   ```dart
   // Missing: IncomingCallOverlay widget
   // Should show: Caller name, avatar, ringing animation
   // Should provide: Accept button → show CallingView with video
   //                 Reject button → send call-rejected signal
   ```

3. **Remote Video Rendering** - CallingView only shows local video
   - [ ] Receive remote MediaStream from peer connection
   - [ ] Display RTCVideoRenderer for remote stream
   - [ ] Switch between local/remote video or picture-in-picture

4. **Call State Machine** - No centralized call state management
   - States needed: `idle` → `ringing` → `connecting` → `connected` → `ended`
   - Transitions: Incoming/outgoing, accept/reject, connection success/failure
   - Currently: Only `_isCallActive` boolean (insufficient)

5. **Notifications** - No local notifications for:
   - Incoming messages (when app in background)
   - Incoming calls (alert/ringtone)
   - Call missed
   - Connection errors

6. **Error Recovery**
   - [ ] Socket disconnect handling → auto-reconnect with exponential backoff
   - [ ] Peer connection failure → graceful error message
   - [ ] Network interruption → pause/resume logic

7. **Call History** - No UI to view past calls
   - [ ] Need to fetch call history from backend
   - [ ] Display duration, timestamp, missed calls

8. **Message Unread Status** - No tracking of read/unread messages
   - [ ] Add `read` field to message model
   - [ ] Mark messages as read when opened
   - [ ] Show unread badge in conversation list

---

## PRIORITY FIXES NEEDED

### **Tier 1 - Critical for MVP**
1. **Incoming Call Handler** - Socket listener in main.dart for `incoming-call`
   - Show incoming call overlay with accept/reject
   - Pass call context (userId, name, avatar) to CallingView

2. **Remote Video Streaming** - RTCVideoRenderer for remote peer
   - Connect `onRemoteStreamAdded` callback to UI
   - Display remote video in CallingView

3. **Call State Management** - Replace boolean with proper state machine
   - Manage `ringing` → `connecting` → `connected` states
   - Disable UI actions during transitions

### **Tier 2 - Important for UX**
4. **Local Notifications** - Flutter `flutter_local_notifications` for:
   - Incoming call alert (with ringtone)
   - New message notification
   - Missed call log

5. **Socket Reconnection** - Automatic retry with backoff
   - Track connection state
   - Attempt reconnect on disconnect
   - Notify UI of connection status

6. **Message Read Receipts** - Track message read status
   - Add `read` and `read_at` columns to DB
   - Socket event for "message-read"

### **Tier 3 - Polish**
7. **Call History** - Fetch and display past calls
8. **Unread Message Badges** - Show counts in conversation list
9. **Typing Indicators** - "User is typing..." display
10. **Voice Messages** - Record/playback audio messages

---

## Database Schema Updates Needed

```sql
-- Call history table
CREATE TABLE IF NOT EXISTS calls (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  from_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  to_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'initiated', -- initiated | ringing | accepted | rejected | ended
  started_at timestamptz,
  ended_at timestamptz,
  duration_seconds integer,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Message read status
ALTER TABLE messages ADD COLUMN IF NOT EXISTS read boolean DEFAULT false;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS read_at timestamptz;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_calls_users ON calls(from_user_id, to_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_read ON messages(to_user_id, read);
```

---

## Implementation Roadmap

### Phase 1: Incoming Calls (8-10 hours)
- [ ] Add `incoming-call` socket handler to backend
- [ ] Add `incoming-call` listener to Flutter main.dart
- [ ] Create IncomingCallOverlay widget
- [ ] Add accept/reject handlers
- [ ] Test end-to-end call flow

### Phase 2: Remote Video & State Management (6-8 hours)
- [ ] Implement remote stream rendering
- [ ] Add call state enum (idle, ringing, connecting, connected, ended)
- [ ] Update CallingView to reflect state
- [ ] Add error handling for peer connection failures

### Phase 3: Notifications & Recovery (8-10 hours)
- [ ] Implement local notifications
- [ ] Add socket reconnection logic
- [ ] Add message read receipts
- [ ] Handle network interruptions gracefully

### Phase 4: Call History & Polish (6-8 hours)
- [ ] Add call history UI
- [ ] Implement unread badges
- [ ] Add typing indicators
- [ ] Test and optimize

---

## Testing Checklist

- [ ] Can initiate outgoing call to another user
- [ ] Remote user receives incoming call notification
- [ ] Remote user can accept/reject call
- [ ] Video streams display correctly on both ends
- [ ] Audio works bidirectionally
- [ ] Can mute/unmute, toggle video
- [ ] Call ends cleanly
- [ ] Can send/receive messages in real-time
- [ ] Messages persist to database
- [ ] Socket reconnects after network interruption
- [ ] Notifications appear for missed calls/messages
- [ ] App handles concurrent chat and call properly

---

## Files to Create/Modify

### Backend
- [ ] `socket.ts` - Add incoming call + rejection handlers
- `init-db.sql` - Add calls table and message read status

### Frontend
- [ ] `lib/widgets/incoming_call_overlay.dart` - NEW
- [ ] `lib/models/call_state.dart` - NEW (enum for call states)
- [ ] `lib/services/socket_service.dart` - Add incoming-call listener
- [ ] `lib/services/call_service.dart` - Add remote stream handling
- [ ] `lib/screens/communication/calling_view.dart` - Update for states + remote video
- [ ] `lib/main.dart` - Add incoming call handler
- [ ] `pubspec.yaml` - Add `flutter_local_notifications`

