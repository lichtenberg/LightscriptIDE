// lightscript_api.cpp
#include "lightscript_api.h"

#include "tokenstream.hpp"
#include "parser.hpp"
#include "schedule.hpp"
#include "lsinternal.h"
#include "playback.h"
#include <memory>
#include <string>
#include <cstring>

extern "C" {
#include "ls_lexer.h"   // brings in YY_BUFFER_STATE, yy_scan_bytes, yylex, etc.
lstoken_t yylval;
}


// ---- Callback hooks from header ----
static void (*g_time_cb)(double) = nullptr;
static void (*g_status_cb)(int iserror, const char*) = nullptr;
extern "C" {
void (*g_playback_end_cb)(void) = nullptr;
};

// ---- Single context (simple for now; you can make this per-session later) ----
struct LSContext {
    LSTokenStream ts;
    LSParser parser;
    LSSchedule sched;
    LSScript script;
    Playback playback;

    // device / playback
    std::string deviceName = "";

    // Script directory
    std::string scriptDirectory = ".";
    
    // error reporting
    int         last_error_line = 0;
    std::string last_error_msg = "";

    LSContext() {
    }

    void resetAll() {
        ts.reset();
        sched.reset();
        script.reset();
        last_error_line = 0;
        last_error_msg.clear();
    }

    void report_error(const char* msg, int line = 0) {
        last_error_line = line;
        last_error_msg  = msg ? msg : "";
        if (g_status_cb) g_status_cb(1, last_error_msg.c_str());
    }
};

static LSContext* g = nullptr;


// If you have your own error facility inside LSParser/LSTokenStream,
// consider wiring it so they call back into g->report_error(...).
extern "C" {
int lsprintf(const char * str, ...)
{
    static char textbuf[512];
    int ret;
    va_list args;
    va_start(args, str);
    ret = vsnprintf(textbuf, sizeof(textbuf)-1, str, args);
    va_end(args);
    if (g_status_cb) g_status_cb(0,textbuf);
    return ret;
}
int lsprinterr(const char * str, ...)
{
    static char textbuf[512];
    int ret;
    va_list args;
    va_start(args, str);
    ret = vsnprintf(textbuf, sizeof(textbuf)-1, str, args);
    va_end(args);
    if (g_status_cb) g_status_cb(1,textbuf);
    return ret;
}

};

extern "C" {

int lightscript_init(void) {
    if (!g) g = new LSContext();
    // If Playback needs init, do it here
    return 0;
}

static void _timecb1(void *arg, double f)
{
    if (g_time_cb) (*g_time_cb)(f);
}
void lightscript_set_time_callback(void (*cb)(double)) {
    g->playback.set_time_callback(_timecb1, NULL);
    g_time_cb = cb;
}
    
void lightscript_set_status_callback(void (*cb)(int, const char*)) {
    g_status_cb = cb;
}

void lightscript_set_playback_end_callback(void (*cb)(void)) {
    g_playback_end_cb = cb;
}

void lightscript_set_script_directory(const char *str)
{
    if (!g) return;
    g->scriptDirectory = str;
}

int lightscript_set_device(const char* devname) {
    if (!g) return -1;
    g->deviceName = devname ? devname : "";
    return 0;
}

int lightscript_get_error_line(void) {
    return g ? g->ts.getErrorLine() : 0;
}

int lightscript_reset(void) {
    if (!g) return -1;
    g->resetAll();
    lsprintf("Reset.");
    return 0;
}

int lightscript_tokenize_file(const char* filename)
{
    if (!g || !filename) return -1;
    lstoktype_t t;
    
    lsprintf("Loading file: %s", filename);
    yyin = fopen(filename, "rb");
    if (!yyin) {
        lsprinterr("Could not open %s : %s", filename, strerror(errno));  return -2;
    }
    yyrestart(yyin);
    yylineno = 1;
    // Call the lexer and read all the tokens into the token stream.
    while ((t = (lstoktype_t) yylex())) {
        LSToken tok = LSToken(t, filename, yylineno, &yylval);
        g->ts.add(tok);
    }
    
    fclose(yyin);
    return 0;
}

int lightscript_parse_script(void)
{
    lsprintf("Parsing script files");
    
    g->parser.init(&g->ts, &g->script);   // use your actual init
    try {
        g->parser.parseTopLevel();
    } catch (...) {
        //g->report_error("parse exception", g->parser.currentLine());
        return -3;
    }
    lsprintf("Parsed file.");
    if (g->sched.generate(g->script) == false) {
        g->report_error("Could not generate schedule",0);
        return -4;
    }
    lsprintf("Schedule generated.");
    return 0;
}


int lightscript_tokenize_string(const char* scriptText)
{
    if (!g || !scriptText) return -1;
    lstoktype_t t;

    // Scan from memory buffer with Flex
    YY_BUFFER_STATE buf = yy_scan_bytes(scriptText, (int)std::strlen(scriptText));
    yylineno = 1;

    while ((t = (lstoktype_t) yylex())) {
        LSToken tok = LSToken(t, "script", yylineno, &yylval);
        g->ts.add(tok);
    }

    yy_delete_buffer(buf);

    return 0;
}

int lightscript_connect(void) {
    if (!g) return -1;
    if (g->playback.play_opendevice((char *) g->deviceName.c_str()) < 0) {
        g->report_error("connect failed", 0);
        return -2;
    }
    lsprintf("Connected.");
    return 0;
}

int lightscript_disconnect(void) {
    if (!g) return 0;
    g->playback.play_closedevice();
    lsprintf("Disconnected.");
    return 0;
}

int lightscript_playback_start(int with_music) {
    if (!g) return -1;

    g->playback.play_setdir(g->scriptDirectory);
    g->playback.play_init(&g->script, &g->sched);
    g->playback.play_initdevice();

    if (g->playback.play_start(with_music != 0) < 0) {
        g->report_error("playback start failed", 0);
        return -3;
    }
    lsprintf("Playback started.");
    return 0;
}

void lightscript_playback_wait(void)
{
    if (!g) return;
    g->playback.play_wait();
}

void lightscript_playback_stop(void) {
    if (!g) return;
    g->playback.play_interrupt();
    g->playback.play_wait();
    lsprintf("Playback stopped.");
}

void lightscript_shutdown(void) {
    if (!g) return;
    // RAII cleans up everything
    delete g;
    g = nullptr;
    lsprintf("Shutdown.");
}

} // extern "C"
