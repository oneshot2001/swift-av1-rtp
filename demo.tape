# swift-av1-rtp Demo GIF
# Demonstrates av1dump CLI parsing AV1 RTP payloads

Output demo.gif

Set Shell "zsh"
Set FontSize 15
Set Width 880
Set Height 560
Set Theme "Catppuccin Mocha"
Set Padding 20
Set TypingSpeed 50ms
Set PlaybackSpeed 1

# Pre-build in background
Hide
Type "cd ~/swift-av1-rtp && swift build -q 2>/dev/null"
Enter
Sleep 8s
Show

Sleep 500ms

# --- Part 1: Keyframe with Sequence Header ---
Type "# 1) Parse a keyframe RTP payload (Sequence Header + Frame)"
Enter
Sleep 800ms

Type "swift run -q av1dump demo-keyframe.bin"
Enter
Sleep 4s

# Pause to read
Sleep 3s

# --- Part 2: Interframe ---
Type "# 2) Parse an interframe RTP payload"
Enter
Sleep 800ms

Type "swift run -q av1dump demo-interframe.bin"
Enter
Sleep 4s

# Pause to read
Sleep 3s

# --- Part 3: Hex mode ---
Type "# 3) Parse from hex-encoded payload (inline)"
Enter
Sleep 800ms

Type "swift run -q av1dump --hex 18083000DEADBEEF"
Enter
Sleep 4s

# Pause to read
Sleep 3s
