/*  *********************************************************************
    *  LightScript - A script processor for LED animations
    *  
    *  Picolight Playback
    *  
    *  Author:  Mitch Lichtenberg
    ********************************************************************* */


#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <fcntl.h>
#include <errno.h>

#include <vector>
#include <string>
#include "schedule.hpp"
#include "symtab.hpp"

#include "lsinternal.h"

#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/ip.h>
#include <arpa/inet.h>
#include <netinet/tcp.h>
#include <netdb.h>

#include "playback.h"
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#include <dirent.h>


#define MSGSIZE 16


Playback::Playback()
{
    device = -1;
    epoch = 0;
    offAnim = 0;
    start_offset = 0;
    play_please_stop = false;
    musicpos = 0;
    musicend = 0;
    curscript = NULL;
    cursched = NULL;
}

Playback::~Playback()
{
    // Ensure the thread is gone.
    play_please_stop = true;
    play_wait();
}


static int playMusicFile(const char *filename, Playback *player, double start_cue)
{
    AVAudioPlayer *audioPlayer;
    NSString *path = [NSString stringWithFormat:@"file://%@", [NSString stringWithCString:filename encoding:NSUTF8StringEncoding]];
    NSURL *soundUrl = [NSURL URLWithString:path];
    NSError *error;
    bool playIt = false;
    
    //NSLog(@"Music playback URL = %@",[soundUrl absoluteURL]);
    audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:soundUrl error:&error];

    
    if (error) {
           NSLog(@"Error in audioPlayer: %@", [error localizedDescription]);
           return -1;
       } else {
           [audioPlayer prepareToPlay];
           playIt = true;
           //_audioPlayer.enableRate = YES;
           //_audioPlayer.volume = 0.5f;
           //_audioPlayer.rate = 1.0f;
       }
    
    if (playIt) {
        [audioPlayer play];
        if (start_cue != 0.0) {
            audioPlayer.currentTime = start_cue;
        }

        while (audioPlayer.playing) {
            NSTimeInterval playTime = [audioPlayer currentTime];
            if (player->player_callback(playTime) == 0) {
                break;
            }
            [NSThread sleepForTimeInterval:0.01];
        }

        [audioPlayer stop];
    }

    return 0;
}

static char *findpicolight(void)
{
    DIR *dir;
    struct dirent *dp;
    char *devicenames[10];
    int picked = 0;
    int devcnt = 0;
    int i;
    static char devname[256];

    dir = opendir("/dev");              // We're going to look through /dev for files
    while ((dp = readdir(dir)) != NULL) {
        if ((devcnt < 10) && (strstr(dp->d_name,"cu.usbmodem"))) {
            devicenames[devcnt++] = strdup(dp->d_name);
        }
    }
    closedir(dir);


    if (devcnt == 0) {
        lsprinterr("No Picolight boards appear to be connected, is the power on?");
        return NULL;
    } else if (devcnt == 1) {
        picked = 0;
        lsprinterr("Found only one device, trying /dev/%s",devicenames[0]);
    } else {
        lsprinterr("More than one possible device found.  Taking the first one, /dev/%s",devicenames[0]);
    }


    if (devcnt > 0) {
        snprintf(devname,sizeof(devname)-1,"/dev/%s",devicenames[picked]);
    }

    for (i = 0; i < devcnt; i++) {
        free(devicenames[i]);
    }

    if (devcnt == 0) {
        return NULL;
    }
    return devname;

}



static void msleep(int ms)
{
    struct timespec ts;

    ts.tv_sec = 0;
    ts.tv_nsec = ms * 1000000;
    nanosleep(&ts,NULL);
}

double Playback::current_time(void)
{
    struct timeval tv;

    gettimeofday(&tv,NULL);

    return ((double) (tv.tv_sec - epoch)) + ((double)(tv.tv_usec)/1000000.0);
}


static int send_command(int device, lsmessage_t *msg)
{
    uint8_t sync[2];
    int txlen;

    if (device <= 0) {
        return -1;
    }

    sync[0] = 0x02;
    sync[1] = 0xAA;
    if (write(device, sync, sizeof(sync)) != sizeof(sync)) {
        perror("Write Error to Picolight [sync]");
        exit(1);
    }

    txlen = LSMSG_HDRSIZE + msg->ls_length;

    if (write(device, msg, txlen) != txlen) {
        perror("Write Error to Picolight [cmd]");
        exit(1);
    }

    return 0;
}

static ssize_t readdata(int device, uint8_t *buf, int len)
{
    ssize_t res;
    int ttl = 0;

    while (len > 0) {
        res = read(device, buf, len);
        if (res <= 0) {
            lsprinterr("Read error from PicoLight: %d\n",res);
            exit(1);
        }
        buf += res;
        len -= res;
        ttl += res;
    }

    return ttl;
}


#define STATE_SYNC1 0
#define STATE_SYNC2 1
static ssize_t recv_response(int device, lsmessage_t *msg)
{
    uint8_t b;
    ssize_t res;
    int reading = 1;
    int state = STATE_SYNC1;

    if (device <= 0) {
        return -1;
    }

    #if 0
    for (;;) {
        if (readdata(device, &b,1) == 1) { printf("%02X ",b); fflush(stdout);}
        else {
            printf("read error\n");
            exit(1);
        }
    }
    #endif

    while (reading) {
        if (readdata(device, &b,1) < 1) {
            printf("Read error from Picolight [sync]\n");
            exit(1);
        }
        switch (state) {
            case STATE_SYNC1:
                if (b == 0x02) {
                    state = STATE_SYNC2;
                }
                break;
            case STATE_SYNC2:
                if (b == 0xAA) {
                    reading = 0;
                } else {
                    state = STATE_SYNC1;
                }
        }
    }

    memset(msg,0,sizeof(lsmessage_t));

    if (readdata(device,(uint8_t *) msg,LSMSG_HDRSIZE) != LSMSG_HDRSIZE) {
        printf("Read error from Picolight [hdr]\n");
            exit(1);
    }

    int rxlen = msg->ls_length;

    if (rxlen != 0) {
        if ((res = readdata(device,(uint8_t *) &(msg->info), rxlen)) != rxlen) {
            printf("Read error from Picolight [payload] %ld\n",res);
            exit(1);
        }
    }

    return 0;
            
}

static void send_animate(int device, uint32_t *strips, uint16_t anim,  uint16_t speed, uint16_t option, uint32_t color)
{
    lsmessage_t msg;

    memset(&msg,0,sizeof(msg));

    for (int i = 0; i < MAXVSTRIPS/32; i++) {
        msg.info.ls_animate.la_strips[i] = strips[i];
    }

    msg.info.ls_animate.la_anim = anim;
    msg.info.ls_animate.la_speed = speed;
    msg.info.ls_animate.la_option = option;
    msg.info.ls_animate.la_color = color;
    msg.ls_length = sizeof(lsanimate_t);
    msg.ls_command = LSCMD_ANIMATE;

    send_command(device, &msg);
}

void Playback::play_setdir(std::string dir)
{
    scriptDirectory = dir;
}

void Playback::check_version(void)
{
    lsmessage_t msg;

    msg.ls_command = LSCMD_VERSION;
    msg.ls_length = 0;

    send_command(device, &msg);
    recv_response(device, &msg);

    lsprintf("Protocol version: %u     Firmware Version %u.%u    Hardware %u\n",
           msg.info.ls_version.lv_protocol,
           msg.info.ls_version.lv_major,
           msg.info.ls_version.lv_minor,
           msg.info.ls_version.lv_hwtype);
}


// private
int Playback::upload_config(LSScript *script)
{
    lsmessage_t txMessage;
    lsmessage_t rxMessage;
    int i;

    lsprintf("Resetting panel");
    // Send a RESET command
    memset(&txMessage,0,sizeof(txMessage));
    txMessage.ls_command = LSCMD_RESET;
    txMessage.ls_length = 0;
    send_command(device, &txMessage);
    recv_response(device, &rxMessage);

    lsprintf("Sending physical strips");
    // Send over the physical strips
    for (i = 0; i < MAXPSTRIPS; i++) {
        uint32_t info = script->physicalStrips[i].info;
        if (PSTRIP_COUNT(info) > 0) {
            memset(&txMessage,0,sizeof(txMessage));
            txMessage.ls_command = LSCMD_SETPSTRIP;
            txMessage.ls_length = sizeof(lspstrip_t);
            txMessage.info.ls_pstrip.lp_pstrip = info;
            send_command(device, &txMessage);
            recv_response(device, &rxMessage);
        }
    }
            

    lsprintf("Sending virtual strips");
    // Send over the logical strips
    for (i = 0; i < script->virtualStripCount; i++) {
        VStrip_t *vstrip = &script->virtualStrips[i];
        memset(&txMessage,0,sizeof(txMessage));
        txMessage.ls_command = LSCMD_SETVSTRIP;
        txMessage.ls_length = sizeof(lsvstrip_t);
        txMessage.info.ls_vstrip.lv_idx = i;
        txMessage.info.ls_vstrip.lv_count = vstrip->substripCount;
        memcpy(txMessage.info.ls_vstrip.lv_substrips,
               vstrip->substrips,
               vstrip->substripCount * sizeof(uint32_t));
        send_command(device, &txMessage);
        recv_response(device, &rxMessage);
    }
            
    lsprintf("Initializing panel with new config");
    // Send the INIT command
    memset(&txMessage,0,sizeof(txMessage));
    txMessage.ls_command = LSCMD_INIT;
    txMessage.ls_length = 0;
    send_command(device, &txMessage);
    recv_response(device, &rxMessage);

    return 0;
}


int Playback::env_getenv(char *name, char *val, int vallen)
{
    lsmessage_t txMessage;
    lsmessage_t rxMessage;

    txMessage.ls_command = LSCMD_EEPROM;
    txMessage.ls_length = sizeof(lseeprom_t);
    txMessage.info.ls_eeprom.le_subcmd = LSEEPROM_GETENV;
    strncpy((char *) txMessage.info.ls_eeprom.le_data, name, LSEEPROM_MAXDATA);
    send_command(device, &txMessage);
    recv_response(device, &rxMessage);

    if (rxMessage.info.ls_eeprom.le_data[0] == 0) {
        return -1;
    }
    strncpy(val, (char *) rxMessage.info.ls_eeprom.le_data, vallen);

    return 0;
}

int Playback::env_setenv(char *name, char *val)
{
    lsmessage_t txMessage;
    lsmessage_t rxMessage;

    txMessage.ls_command = LSCMD_EEPROM;
    txMessage.ls_length = sizeof(lseeprom_t);
    txMessage.info.ls_eeprom.le_subcmd = LSEEPROM_SETENV;
    snprintf((char *) txMessage.info.ls_eeprom.le_data, LSEEPROM_MAXDATA, "%s=%s",name,val);
    send_command(device, &txMessage);
    recv_response(device, &rxMessage);
    return 0;
}

int Playback::env_listenv(char *val, int vallen)
{
    lsmessage_t txMessage;
    lsmessage_t rxMessage;

    txMessage.ls_command = LSCMD_EEPROM;
    txMessage.ls_length = sizeof(lseeprom_t);
    txMessage.info.ls_eeprom.le_subcmd = LSEEPROM_PRINTENV;
    txMessage.info.ls_eeprom.le_data[0] = 0;
    send_command(device, &txMessage);
    recv_response(device, &rxMessage);

    if (rxMessage.info.ls_eeprom.le_data[0] == 0) {
        return -1;
    }
    strncpy(val, (char *) rxMessage.info.ls_eeprom.le_data, vallen);

    return 0;
}

int Playback::env_eraseall(void)
{
    lsmessage_t txMessage;
    lsmessage_t rxMessage;

    txMessage.ls_command = LSCMD_EEPROM;
    txMessage.ls_length = sizeof(lseeprom_t);
    txMessage.info.ls_eeprom.le_subcmd = LSEEPROM_ERASEALL;
    txMessage.info.ls_eeprom.le_data[0] = 0;
    send_command(device, &txMessage);
    recv_response(device, &rxMessage);

    return 0;
}

int Playback::reset_to_dfu(void)
{
    lsmessage_t txMessage;
    lsmessage_t rxMessage;

    txMessage.ls_command = LSCMD_DFU;
    txMessage.ls_length = 0;
    send_command(device, &txMessage);
    recv_response(device, &rxMessage);

    return 0;
}


// Private
void Playback::play_events(LSSchedule *sched, double start_cue, double end_cue)
{
    int idx = 0;
    int events = sched->size();
    double start_time;

    start_time = current_time() + start_offset;

    if (start_cue != 0.0) {
        while (idx < events) {
            schedcmd_t *cmd = sched->getAt(idx);
            if (cmd->time < start_cue) {
                idx++;
            } else {
                break;
            }
        }
    }
    
    last_offset = 0;
    
    while (!play_please_stop && (idx < events)) {
        double now;

        schedcmd_t *cmd = sched->getAt(idx);

        // Figure out the difference between the time stamp
        // at the start and now.
        now = current_time() - start_time + start_cue;

        if ((now - last_offset) >= 0.1) {
            last_offset = now;
            if (time_callback) (*time_callback)(time_callback_arg, now);
        }

        // If the current time is past the script command's time,
        // do the command.

        if (now >= cmd->time) {
            unsigned int anim;

            anim = cmd->animation;
            if (cmd->direction) anim |= 0x8000;
            
            sched->printSchedEntry(cmd);
            if (cmd->comment.c_str()[0] == '\0') {
                send_animate(device, cmd->stripmask, anim, cmd->speed, cmd->option, cmd->palette);
            }

            idx++;
        }

        if ((end_cue != 0) && (now > (end_cue))) {
            break;
        }
    }

}

void Playback::set_time_callback(void (*callback)(void *arg,double), void *arg)
{
    time_callback = callback;
    time_callback_arg = arg;
}

int Playback::player_callback(double now)
{
    // If the current time is past the script command's time,
    // do the command.

    if (musicpos == musicend) {
        // End of script, stop playing
        return 0;
    }

    if (play_please_stop) {
        return 0;
    }

    if ((now - last_offset) >= 0.1) {
        last_offset = now;
        if (time_callback) (*time_callback)(time_callback_arg, now);
    }

    schedcmd_t *cmd = (schedcmd_t *) cursched->getAt(musicpos);

    if ((curscript->lss_endcue != 0) && (now >= curscript->lss_endcue)) {
        // Past end cue, stop
        return 0;
    }

    if (now >= cmd->time) {
        unsigned int anim;

        anim = cmd->animation;
        if (cmd->direction) anim |= 0x8000;
            
        cursched->printSchedEntry(cmd);
        if (cmd->comment.c_str()[0] == '\0') {
            send_animate(device, cmd->stripmask, anim, cmd->speed, cmd->option, cmd->palette);
        }

        musicpos++;
    }

    // Keep going
    return 1;

}

// Private
void Playback::play_music(LSSchedule *sched, double start_cue, double end_cue, std::string music)
{
    musicpos = 0;
    musicend = sched->size();

    last_offset = 0;
    // Seek in script to cue point

    if (start_cue != 0.0) {
        while (musicpos != musicend) {
            schedcmd_t *cmd = sched->getAt(musicpos);
            if (cmd->time > start_cue) break;
            musicpos++;
        }

        // We started past the end of the script, bail.
        if (musicpos == musicend) {
            return;
        }
    }

    std::string musicPath = scriptDirectory + "/" + music;
    lsprintf("Playing music file: %s",musicPath.c_str());
    playMusicFile(musicPath.c_str(), this, start_cue);
}


// private
void Playback::play_idle(void)
{
    int v;
    uint32_t mask[MAXVSTRIPS/32];

    if (curscript->lss_idlestrips) {
        try {
            cursched->stripMask(NULL,curscript->lss_idlestrips.get(),mask);
        } catch (int e) {
            return;
        }
    }

    if (curscript->lss_idleanimation != "") {
        if (curscript->animTable.findSym(curscript->lss_idleanimation,v)) {
            send_animate(device, mask, v, 500, 0, 0);
        } else {
            lsprinterr("Warning: idle animation '%s' is not valid",curscript->lss_idleanimation.c_str());
        }
    }
}


// private
void Playback::all_off(void)
{
    uint32_t mask[MAXVSTRIPS/32];

    memset(mask,0,sizeof(mask));
    mask[0] = 0x7FFFFFFF;
    
    // Send "OFF" to everyone, then wait 200ms.
    if (offAnim) {
        send_animate(device,  mask, offAnim, 500, 0, 0);
        msleep(200);
    } 
}

// private
int Playback::play_opentcpdevice(char *hostaddr)
{
    struct sockaddr_in sin;
    struct sockaddr *saddr;
    //struct hostent *hp;
    socklen_t ssize;
    long nport = 4242;
    ssize_t rv;
    int fd;
    //  in_addr_t inaddr;
    struct hostent *hp;

    memset(&sin, 0, sizeof(sin));
    sin.sin_family = AF_INET;

    hp = gethostbyname(hostaddr);

    if (!hp) {
        lsprinterr("Could not resolve hostname '%s'\n",hostaddr);
        return -1;
    }


    /* build the server's Internet address */
    bzero((char *) &(sin), sizeof(sin));
    sin.sin_family = hp->h_addrtype;
    bcopy((char *)hp->h_addr, 
          (char *)&sin.sin_addr.s_addr, hp->h_length);
    sin.sin_family = AF_INET;
    sin.sin_port = htons(nport);
    saddr = (struct sockaddr *) &sin;
    ssize = sizeof(sin);

    fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) {
        return -1;
    }

    rv = connect(fd, saddr, ssize);

    if (rv) {
        lsprinterr("lightscript: connect: %s\n",  strerror(errno));
        return -1;
    }

    int flags = 1; 
    if (setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, (void *)&flags, sizeof(flags))) {
        perror("ERROR: setsocketopt(), TCP_NODELAY");
        exit(0); }
    ; 

    device = fd;
    
    return 0;

}

// private
int Playback::play_openusbdevice(char *devname)
{
    if (devname != NULL) {
        device = open(devname,O_RDWR);

        if (device < 0) {
            lsprinterr("Error: Could not open Picolight device %s: %s\n",devname, strerror(errno));
            return -1;
        }
    } else {
        device = -1;             // No device, just pretend.
    }

    return 0;
}

int Playback::play_opendevice(char *devname)
{
    if ((inet_addr(devname) != INADDR_NONE) ||
        (strstr(devname,".lan") != NULL)) {
        return play_opentcpdevice(devname);
    } else {
        if (!devname || devname[0] == '\0') {
            devname = findpicolight();
            if (devname == NULL) {
                return -1;
            }
        }
        return play_openusbdevice(devname);
    }

}

void Playback::play_closedevice(void)
{
    if (device > 0) {
        close(device);
        device = -1;
    }
}

void Playback::play_initdevice()
{
    check_version();
    upload_config(curscript);
    play_please_stop = false;

    all_off();
    play_idle();
}



int Playback::play_start(int how)
{
    play_with_music = how;
    
    if (curscript->lss_music == "") {
        play_with_music = 0;
        lsprintf("No music specified in the script file, playing without music");
    }

    if (playbackThread.joinable()) {
        lsprinterr("ERROR: playback is running\n");
        return -1;
    }
    playbackThread = std::thread(&Playback::run, this);
    return 0;
}

void Playback::play_wait(void)
{
    if (playbackThread.joinable()) {
        playbackThread.join();
    }
}

extern "C" {
extern void (*g_playback_end_cb)(void);
};

void Playback::run(void)
{    
    time(&epoch);
    
    if (play_with_music == 0) {
        play_events(cursched, curscript->lss_startcue, curscript->lss_endcue);
    } else {
        play_music(cursched, curscript->lss_startcue, curscript->lss_endcue, curscript->lss_music);
    }

    msleep(500);

    all_off();
    play_idle();
    lsprintf("Playback thread is finished");
    if (g_playback_end_cb) (*g_playback_end_cb)();
    
}

void Playback::play_init(LSScript *script, LSSchedule *sched)
{
    std::string offStr = "OFF";
    int v;

    curscript = script;
    cursched = sched;

    // Send "OFF" to everyone, then wait 200ms.
    if (script->animTable.findSym(offStr,v)) {
        offAnim = v;
    }

    play_please_stop = false;
}


void Playback::play_interrupt(void)
{
    play_please_stop = true;
}

