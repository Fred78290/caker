# VNCLib - VNC Server for macOS

A complete VNC server library in Swift for macOS, based on NSView, designed to replace the use of the private `_VZVNCServer` class.

## Features

- **Complete VNC server**: RFB 3.8 protocol implementation
- **Real-time capture**: Automatic capture of NSView content with Metal or Core Graphics
- **Hardware acceleration**: Metal-based GPU acceleration for high performance
- **VNC Authentication**: Support for password-based authentication with DES encryption
- **Automatic resizing**: Handles source view size changes
- **Complete input support**:
  - Keyboard with AZERTY/QWERTY mapping
  - Mouse (clicks, movements, wheel)
  - Bidirectional clipboard
- **Thread-safe**: Optimized asynchronous architecture
- **High performance**: Up to 60 FPS updates with Metal acceleration
- **Performance monitoring**: Built-in render statistics and profiling

## Installation

Copy the `vnclib` folder into your Swift project and add the files to your target.

## Usage

### Basic Setup

```swift
import AppKit

class ViewController: NSViewController, VNCServerDelegate {
    @IBOutlet weak var contentView: NSView!
    private var vncServer: VNCServer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create and configure VNC server
        vncServer = VNCServer(sourceView: contentView, port: 5900)
        vncServer?.delegate = self
        vncServer?.allowRemoteInput = true
        
        do {
            try vncServer?.start()
            print("VNC Server started on port 5900")
        } catch {
            print("Startup error: \(error)")
        }
    }
    
    // MARK: - VNCServerDelegate
    
    func vncServer(_ server: VNCServer, clientDidConnect clientAddress: String) {
        print("VNC client connected: \(clientAddress)")
    }
    
    func vncServer(_ server: VNCServer, clientDidDisconnect clientAddress: String) {
        print("VNC client disconnected: \(clientAddress)")
    }
    
    func vncServer(_ server: VNCServer, didReceiveError error: Error) {
        print("VNC error: \(error)")
    }
    
    // Optional methods to monitor inputs
    func vncServer(_ server: VNCServer, didReceiveKeyEvent key: UInt32, isDown: Bool) {
        print("Key \(key) \(isDown ? "pressed" : "released")")
    }
    
    func vncServer(_ server: VNCServer, didReceiveMouseEvent x: Int, y: Int, buttonMask: UInt8) {
        print("Mouse at (\(x), \(y)) buttons: \(buttonMask)")
    }
}
```

### Advanced Configuration

```swift
// Disable remote inputs
vncServer?.allowRemoteInput = false

// Use random available port (30000-32767)
let randomServer = VNCServer(sourceView: myView, port: 0)
print("Server started on port: \(randomServer.port)")

// Specific port with error handling
let customServer = VNCServer(sourceView: myView, port: 5901)
do {
    try customServer.start()
} catch VNCServerError.portNotAvailable(let port) {
    print("Port \(port) is not available")
} catch {
    print("Error: \(error)")
}

// Stop server
vncServer?.stop()
```

### Metal Acceleration

```swift
// Use Metal acceleration for better performance
let metalServer = VNCServer(sourceView: myView, port: 5900, captureMethod: .metal)

// Monitor performance
vncServer.onPerformanceUpdate = { renderFPS, networkFPS in
    print("Render FPS: \(String(format: "%.1f", renderFPS))")
    print("Network FPS: \(String(format: "%.1f", networkFPS))")
}

// Fallback to Core Graphics if Metal fails
let adaptiveServer = VNCServer(sourceView: myView, port: 5900, captureMethod: .coreGraphics)
```

### With VNC Authentication

```swift
// VNC server with password protection
let secureServer = VNCServer(
    sourceView: myView, 
    port: 5900, 
    captureMethod: .metal,
    password: "mySecretPassword"
)
try secureServer.start()

// No password (no authentication)
let openServer = VNCServer(sourceView: myView, port: 5901)
try openServer.start()

// Change password at runtime
secureServer.password = "newPassword"
```

## Architecture

### Main Classes

- **VNCServer**: Main class managing server and connections
- **VNCFramebuffer**: Capture and management of NSView content
- **VNCConnection**: Management of individual client connections
- **VNCInputHandler**: Processing of keyboard/mouse events
- **VNCKeyMapper**: Mapping of VNC keys to macOS

### Protocols

- **VNCServerDelegate**: Server event notifications
- **VNCConnectionDelegate**: Internal connection management
- **VNCInputDelegate**: Internal input management

## Event Management

### Keyboard
- Complete support for alphanumeric keys
- Function keys (F1-F12)
- Modifiers (Shift, Control, Option, Command)
- Special keys (arrows, navigation)
- Numeric keypad
- Automatic QWERTY ↔ AZERTY mapping

### Mouse
- Left, right, middle clicks
- Cursor movements
- Scroll wheel
- Automatically converted coordinates

### Clipboard
- Automatic synchronization of copied text
- Bidirectional support

## Thread Safety

All operations are thread-safe:
- Dedicated queue for network connections
- Separate queue for framebuffer updates
- Automatic synchronization with main thread for UI events

## Performance

- **30 FPS**: Real-time framebuffer updates
- **Optimized capture**: Uses Core Graphics
- **Change detection**: Only sends necessary updates
- **Memory management**: Automatic resource cleanup

## Security

### Authentication Methods

- **No Authentication**: Default mode for quick setup
- **VNC Auth**: Standard VNC password authentication
  - DES encryption of challenge/response
  - 8-byte password support (padded/truncated)
  - Secure challenge generation

### Security Features

- **Input control**: Toggle remote input via `allowRemoteInput`
- **Network isolation**: Each connection in its own queue
- **Password protection**: Runtime password changes supported
- **Connection filtering**: Delegate-based connection approval

## Supported Protocol

- **RFB 3.8**: Standard VNC protocol version
- **RAW encoding**: Uncompressed pixel format
- **RGBA format**: 32 bits per pixel, depth 24

## Dependencies

- **Foundation**: Basic functionality
- **AppKit**: macOS user interface
- **Network**: Modern network management
- **Carbon**: Keyboard key codes

## Compatibility

- **macOS 10.15+**: Uses Network framework
- **Swift 5.0+**: Modern syntax
- **Xcode 12+**: Development tools

## Complete Example

See source files for complete implementation with:

- Error handling
- Size change notifications
- Detailed logging
- Automatic resource cleanup

## Replacing _VZVNCServer

This library can directly replace `_VZVNCServer`:

```swift
// Old code with _VZVNCServer
// let vncServer = _VZVNCServer(...)

// New code with VNCLib
let vncServer = VNCServer(sourceView: myView, port: 5900)
```

## License

This library is provided under MIT license. See LICENSE file for details.