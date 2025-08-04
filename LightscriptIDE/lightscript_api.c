//
// Temporary stub implementation of lightscript_api.h
// Replace this with the actual C++ wrapper implementation later
//

#include "lightscript_api.h"
#include <stdio.h>
#include <string.h>

// Static callback storage
static void (*g_time_callback)(double) = NULL;
static void (*g_status_callback)(int, const char*) = NULL;

// Static state
static int g_initialized = 0;
static int g_connected = 0;
static int g_playing = 0;
static int g_error_line = 0;

//
// Perform once-only initialization
//
int lightscript_init(void) {
    printf("lightscript_init() - stub\n");
    g_initialized = 1;
    return 0; // success
}

//
// Lightscript callbacks
//
void lightscript_set_time_callback(void (*callback)(double)) {
    printf("lightscript_set_time_callback() - stub\n");
    g_time_callback = callback;
}

void lightscript_set_status_callback(void (*callback)(int iserror, const char *string)) {
    printf("lightscript_set_status_callback() - stub\n");
    g_status_callback = callback;
}

// Set the name of the device to connect to
int lightscript_set_device(const char *devname) {
    printf("lightscript_set_device(%s) - stub\n", devname ? devname : "null");
    return 0; // success
}

// Get error line number
int lightscript_get_error_line(void) {
    printf("lightscript_get_error_line() - stub, returning %d\n", g_error_line);
    return g_error_line;
}

//
// Clear out previous script, free objects, prepare to read a new script
//
int lightscript_reset(void) {
    printf("lightscript_reset() - stub\n");
    g_error_line = 0;
    g_playing = 0;
    if (g_status_callback) {
        g_status_callback(0, "Script reset");
    }
    return 0; // success
}

//
// Read a script file
//
int lightscript_parse_file(const char *filename) {
    printf("lightscript_parse_file(%s) - stub\n", filename ? filename : "null");
    if (g_status_callback) {
        g_status_callback(0, "Parsed file (stub)");
    }
    return 0; // success
}

//
// Read the script as a string
//
int lightscript_parse_string(const char *script) {
    printf("lightscript_parse_string() - stub\n");
    
    // Simulate parsing - check for obvious syntax errors for testing
    if (!script || strlen(script) == 0) {
        if (g_status_callback) {
            g_status_callback(1, "Error: Empty script");
        }
        return 1; // error
    }
    
    // Simulate a parse error on scripts containing "error" (for testing)
    if (strstr(script, "error") != NULL) {
        g_error_line = 5; // simulate error on line 5
        if (g_status_callback) {
            g_status_callback(1, "Parse error: Simulated error on line 5");
        }
        return 1; // error
    }
    
    // Success case
    if (g_status_callback) {
        g_status_callback(0, "Script parsed successfully");
        g_status_callback(0, "Schedule:");
        g_status_callback(0, "  00:00.00 - Start sequence");
        g_status_callback(0, "  00:05.50 - LED pattern 1");
        g_status_callback(0, "  00:12.00 - LED pattern 2");
        g_status_callback(0, "  00:18.75 - End sequence");
    }
    
    return 0; // success
}

//
// Connect, disconnect from device
//
int lightscript_connect(void) {
    printf("lightscript_connect() - stub\n");
    g_connected = 1;
    if (g_status_callback) {
        g_status_callback(0, "Connected to device (stub)");
    }
    return 0; // success
}

int lightscript_disconnect(void) {
    printf("lightscript_disconnect() - stub\n");
    g_connected = 0;
    g_playing = 0;
    if (g_status_callback) {
        g_status_callback(0, "Disconnected from device (stub)");
    }
    return 0; // success
}

//
// Playback start/stop
//
int lightscript_playback_start(int with_music) {
    printf("lightscript_playback_start(with_music=%d) - stub\n", with_music);
    
    if (!g_connected) {
        if (g_status_callback) {
            g_status_callback(1, "Error: Not connected to device");
        }
        return 1; // error
    }
    
    g_playing = 1;
    
    if (g_status_callback) {
        if (with_music) {
            g_status_callback(0, "Starting playback with music (stub)");
        } else {
            g_status_callback(0, "Starting playback without music (stub)");
        }
    }
    
    // Simulate some time updates
    if (g_time_callback) {
        // In real implementation, this would be called from the playback thread
        // For now, just call it once to test the time display
        g_time_callback(0.0);
    }
    
    return 0; // success
}

void lightscript_playback_stop(void) {
    printf("lightscript_playback_stop() - stub\n");
    g_playing = 0;
    
    if (g_status_callback) {
        g_status_callback(0, "Playback stopped (stub)");
    }
    
    if (g_time_callback) {
        g_time_callback(0.0); // reset time to 0
    }
}

//
// Application termination
//
void lightscript_shutdown(void) {
    printf("lightscript_shutdown() - stub\n");
    g_initialized = 0;
    g_connected = 0;
    g_playing = 0;
    g_time_callback = NULL;
    g_status_callback = NULL;
}