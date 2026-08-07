# Football Whistle Field Test Plan

This plan validates whistle-assisted Football clock administration on physical iPhone and Apple Watch devices. Simulator microphone tests do not establish field reliability.

## Environments

1. Quiet room
2. Outdoor field
3. Crowd noise
4. PA system
5. Wind
6. Bluetooth headset
7. No headset
8. Low network coverage
9. Offline game mode
10. Officials Communication Bridge active

## Whistle Cases

1. One Head Referee opening whistle
2. Non-Head-Referee whistle before initial start
3. One crew end-of-play whistle
4. Multiple simultaneous crew whistles
5. Different whistle brands
6. Long whistle
7. Short whistle
8. Nearby field whistles
9. Whistle from stands
10. Repeated plays with normal cadence

## Device Placement

1. iPhone in pocket
2. iPhone on belt
3. iPhone in hand
4. Apple Watch only display
5. Bluetooth headset microphone
6. Built-in phone microphone

## Game Workflow

1. Five-official crew
2. Start Game selected
3. Opening whistle starts clock only from Head Referee device
4. Crew whistle starts one 25-second play clock
5. Timeout stop from Head Referee iPhone
6. Timeout stop from Watch on-screen button
7. App Intent timeout request
8. Two-minute warning pre-alert at Q2 2:05
9. Two-minute warning pre-alert at Q4 2:05
10. Clock correction
11. Offline queueing and reconnection

## Metrics

- True-positive rate
- False-positive rate
- Detection latency
- Duplicate rate
- Missed whistle rate
- Play-clock-start latency
- Battery impact
- Audio-session conflicts
- Watch communication latency
- Bluetooth route stability
- Communication Bridge coexistence

## Production Gate

Do not label whistle detection production-ready until physical devices show acceptable accuracy, latency, duplicate suppression, battery use, Bluetooth behavior, crowd-noise performance, and coexistence with the Officials Communication Bridge.
