#pragma once

#include <atomic>
#include <memory>
#include <string>
#include <thread>
#include <vector>


class Playback {
public:
    Playback();
    ~Playback();

public:
    int play_opendevice(char *devname);
    void play_closedevice(void);
    void play_initdevice(void);
    int play_start(int how);
    void play_wait(void);
    void play_init(LSScript *script, LSSchedule *sched);
    void play_interrupt(void);
    void play_setdir(std::string dir);

    int env_setenv(char *name, char *val);
    int env_getenv(char *name, char *val, int vallen);
    int env_listenv(char *val, int vallen);
    int env_eraseall(void);

    void check_version(void);
    int reset_to_dfu(void);

    void set_time_callback(void (*callback)(void *arg,double), void *arg);

private:
    int device;
    time_t epoch;
    int offAnim;
    double start_offset;
    bool play_please_stop;
    int play_with_music;
    double last_offset;
    void (*time_callback)(void *, double curtime);
    void *time_callback_arg;
    std::string scriptDirectory;

    int musicpos;
    int musicend;
    LSScript *curscript;
    LSSchedule *cursched;

public:
    int player_callback(double curTime);

private:
    int play_openusbdevice(char *devname);
    int play_opentcpdevice(char *hostaddr);

    void all_off(void);
    void play_idle(void);
    void play_events(LSSchedule *sched, double start_cue, double end_cue);
    void play_music(LSSchedule *sched, double start_cue, double end_cue, std::string music);
    double current_time(void);
    int upload_config(LSScript *script);
    void run(void);

private:
    std::thread playbackThread;

};


