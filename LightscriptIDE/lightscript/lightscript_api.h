
#pragma once

#ifdef __cplusplus
extern "C" {
#endif

//
// Perform once-only initialization
//
int lightscript_init(void);

//
// Lightscript callbacks.
// We have a callback to put text into the status window, and another callback to update the playback timer.
//
void lightscript_set_time_callback(void (*callback)(double));
void lightscript_set_status_callback(void (*callback)(int iserror, const char *string));
void lightscript_set_playback_end_callback(void (*callback)(void));

// Set the name of the device to connect to.  Could be an IP address or hostname, or "usb" to
// select the connected USB device, if any.
int lightscript_set_device(const char *devname);

// In the event of a parse error, we can simply retreive the line number of the
// place where the error is and use this to highlight the line in the script.
int lightscript_get_error_line(void);

//
// Clear out previous script, free objects, prepare to read a new script
//
int lightscript_reset(void);

//
// Read a script file (mainly for config files which are read just before the user script is parsed).
//
int lightscript_tokenize_file(const char *filename);

//
// Read the script as a string (as we would retrieve from the STTextView control)
//
int lightscript_tokenize_string(const char *script);

void lightscript_set_script_directory(const char *dirname);
//
// Parse the tokenized text
//
int lightscript_parse_script(void);

//
// Connect, disconnect from PicoLaser board
// In general we will connect just before script playback - after parsing, we will connect and
// present a modal dialog "Press OK to start playback"  <ok> <cancel>
//
int lightscript_connect(void);
int lightscript_disconnect(void);

//
// Playback start/stop.
// you can start the playback with or without playing the music file, the with_music argument will be nonzero to enable music playback.
//
int lightscript_playback_start(int with_music);
void lightscript_playback_stop(void);
void lightscript_playback_wait(void);

//
// Applicaton termination
//
void lightscript_shutdown(void);

    //
    // Logging
    //
    int lsprintf(const char * str, ...);
    int lsprinterr(const char * str,...);
    

#ifdef __cplusplus
};
#endif


