# MP4 Parser in Zig (WebAssembly)

A lightweight MP4 parser written in Zig v0.13 targeting WebAssembly, allowing for browser-based MP4 file parsing and playback.

## Features

- Parse MP4 files directly in the browser using WebAssembly
- Identify MP4 box structures (ftyp, moov, mdat, etc.)
- Display box types and sizes in the console
- Stream video playback of the parsed MP4 file
- Drag-and-drop file upload interface
- Minimal dependencies (pure Zig implementation)

## Getting Started

### Prerequisites

- [Zig 0.13.0](https://ziglang.org/download/) or newer
- Python (for serving the web application)
- A modern web browser with WebAssembly support

### Building and Running

1. Clone this repository:
   ```
   git clone https://github.com/yourusername/fun-mp4-parser.git
   cd fun-mp4-parser
   ```

2. Build the project:
   ```
   zig build
   ```

3. Deploy and run the web server:
   ```
   zig build run
   ```

4. Open your browser and navigate to `http://localhost:8000`

### Development Commands

- `zig build` - Build the WebAssembly module
- `zig build deploy` - Build and copy files to the www directory
- `zig build run` - Build, deploy, and start the HTTP server

## Implementation Details

- Uses a freestanding WebAssembly target
- Implements custom memory management for WebAssembly constraints
- Parses MP4 box structure without external dependencies
- Communicates between Zig and JavaScript via WebAssembly imports/exports

## Future Enhancements

- Extract and display MP4 metadata
- Support for streaming MP4 formats
- Add visual effects based on MP4 byte data
- Implement more sophisticated memory management for larger files

## License

This project is open source and available under the [MIT License](LICENSE).
