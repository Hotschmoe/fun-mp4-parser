// MP4 Parser in Zig v0.13
// Build target: WebAssembly
// Simple MP4 parser that logs bytes to browser console

// Import the standard library, but we'll be careful about what we use
const std = @import("std");

// WASM imports for browser interaction
extern "env" fn consoleLog(ptr: [*]const u8, len: usize) void;
extern "env" fn createVideoElement(ptr: [*]const u8, len: usize) void;

// Box types for MP4 format
const BoxType = struct {
    type_code: [4]u8,

    fn init(code: []const u8) BoxType {
        var result = BoxType{ .type_code = undefined };
        // Manual copy instead of std.mem.copy
        for (code, 0..) |byte, i| {
            if (i < 4) result.type_code[i] = byte;
        }
        return result;
    }

    fn eql(self: BoxType, other: []const u8) bool {
        // Manual comparison instead of std.mem.eql
        if (other.len < 4) return false;
        for (0..4) |i| {
            if (self.type_code[i] != other[i]) return false;
        }
        return true;
    }
};

// MP4 Box header structure
const BoxHeader = struct {
    size: u32,
    type_code: BoxType,
    extended_size: ?u64,

    fn totalSize(self: BoxHeader) u64 {
        return if (self.size == 1) self.extended_size.? else self.size;
    }
};

// Simple memory buffer for processing data
var buffer: [1024 * 1024]u8 = undefined; // 1MB buffer
var buffer_used: usize = 0;

// Add data to our buffer
export fn addData(ptr: [*]const u8, len: usize) void {
    if (buffer_used + len <= buffer.len) {
        // Manual copy instead of std.mem.copy
        for (0..len) |i| {
            buffer[buffer_used + i] = ptr[i];
        }
        buffer_used += len;
        logString("Added data chunk to buffer");
    } else {
        logString("Buffer overflow, can't add more data");
    }
}

// Parse the MP4 file and extract basic information
export fn parseMP4() void {
    var offset: usize = 0;

    logString("Starting MP4 parsing");

    while (offset + 8 <= buffer_used) {
        const header = parseBoxHeader(buffer[offset..], &offset);
        const box_size = header.totalSize();

        // Log the box type
        var msg_buf: [64]u8 = undefined;
        const msg = formatBoxMessage(&msg_buf, header.type_code.type_code, box_size);

        logString(msg);

        // Skip to the next box
        if (box_size > 0 and offset + box_size <= buffer_used) {
            offset += @intCast(box_size - (offset - (offset - 8)));
        } else {
            // If we can't determine size or it's beyond our buffer, stop
            break;
        }
    }

    // Create a video element in the browser with data URL for playback
    createVideoUrl();
}

// Format a message about a box (simplified version without std.fmt)
fn formatBoxMessage(buf: []u8, type_code: [4]u8, size: u64) []u8 {
    const prefix = "Found box: ";
    var pos: usize = 0;

    // Copy prefix
    for (prefix) |c| {
        buf[pos] = c;
        pos += 1;
    }

    // Copy type code
    for (type_code) |c| {
        buf[pos] = c;
        pos += 1;
    }

    // Add separator
    const separator = ", size: ";
    for (separator) |c| {
        buf[pos] = c;
        pos += 1;
    }

    // Convert size to string (simple implementation)
    var size_copy = size;
    var digits: [20]u8 = undefined; // Max 20 digits for u64
    var digit_count: usize = 0;

    // Handle zero case
    if (size == 0) {
        buf[pos] = '0';
        pos += 1;
    } else {
        // Extract digits in reverse order
        while (size_copy > 0) {
            digits[digit_count] = @intCast((size_copy % 10) + '0');
            size_copy /= 10;
            digit_count += 1;
        }

        // Copy digits in correct order
        var i: usize = digit_count;
        while (i > 0) {
            i -= 1;
            buf[pos] = digits[i];
            pos += 1;
        }
    }

    // Add " bytes" suffix
    const suffix = " bytes";
    for (suffix) |c| {
        buf[pos] = c;
        pos += 1;
    }

    return buf[0..pos];
}

// Helper function to log sample of bytes to the console
export fn logBytes(count: usize) void {
    const bytes_to_log = min(count, buffer_used);
    var i: usize = 0;

    while (i < bytes_to_log) {
        var log_buf: [128]u8 = undefined;
        const end = min(i + 16, bytes_to_log);
        var log_pos: usize = 0;

        // Format position (simplified hex formatting)
        log_pos += formatHex(log_buf[log_pos..], i, 8);
        log_buf[log_pos] = ':';
        log_pos += 1;
        log_buf[log_pos] = ' ';
        log_pos += 1;

        // Format hex values
        var j: usize = i;
        while (j < end) : (j += 1) {
            log_pos += formatHex(log_buf[log_pos..], buffer[j], 2);
            log_buf[log_pos] = ' ';
            log_pos += 1;
        }

        logString(log_buf[0..log_pos]);
        i = end;
    }
}

// Simple min function
fn min(a: usize, b: usize) usize {
    return if (a < b) a else b;
}

// Format a number as hex
fn formatHex(buf: []u8, value: usize, width: usize) usize {
    const hex_chars = "0123456789ABCDEF";
    var pos: usize = 0;

    // Add "0x" prefix
    buf[pos] = '0';
    pos += 1;
    buf[pos] = 'x';
    pos += 1;

    // Convert to hex
    var shift: usize = width * 4;
    while (shift > 0) {
        shift -= 4;
        const digit = (value >> @intCast(shift)) & 0xF;
        buf[pos] = hex_chars[digit];
        pos += 1;
    }

    return pos;
}

// Parse an MP4 box header
fn parseBoxHeader(data: []u8, offset: *usize) BoxHeader {
    // Read size (big-endian u32)
    const size = readU32BE(data, 0);

    // Read type code
    const type_code = BoxType.init(data[4..8]);

    var header = BoxHeader{
        .size = size,
        .type_code = type_code,
        .extended_size = null,
    };

    // Update offset, accounting for the header we just read
    offset.* += 8;

    // If this is a large box, read the extended size (8 more bytes)
    if (header.size == 1 and offset.* + 8 <= data.len) {
        header.extended_size = readU64BE(data, 8);
        offset.* += 8;
    }

    return header;
}

// Read a big-endian u32
fn readU32BE(data: []u8, offset: usize) u32 {
    return @as(u32, data[offset]) << 24 |
        @as(u32, data[offset + 1]) << 16 |
        @as(u32, data[offset + 2]) << 8 |
        @as(u32, data[offset + 3]);
}

// Read a big-endian u64
fn readU64BE(data: []u8, offset: usize) u64 {
    return @as(u64, data[offset]) << 56 |
        @as(u64, data[offset + 1]) << 48 |
        @as(u64, data[offset + 2]) << 40 |
        @as(u64, data[offset + 3]) << 32 |
        @as(u64, data[offset + 4]) << 24 |
        @as(u64, data[offset + 5]) << 16 |
        @as(u64, data[offset + 6]) << 8 |
        @as(u64, data[offset + 7]);
}

// Create a video URL from the buffer for playback
fn createVideoUrl() void {
    // In a real implementation, we might validate and extract necessary MP4 data
    // For simplicity, we'll just pass the whole buffer to the browser
    createVideoElement(&buffer, buffer_used);
}

// Helper to log strings to browser console
fn logString(msg: []const u8) void {
    consoleLog(msg.ptr, msg.len);
}

// Reset the buffer and prepare for new data
export fn resetBuffer() void {
    buffer_used = 0;
    logString("Buffer reset");
}

// Return the number of bytes currently in the buffer
export fn getBufferUsed() usize {
    return buffer_used;
}
