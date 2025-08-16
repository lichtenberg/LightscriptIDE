
#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <errno.h>
#include <dirent.h>
#include <signal.h>

#include "lightscript_api.h"

void inthandler(int x)
{
    printf("[interrupt]\n");
    lightscript_playback_stop();
}

static void timecb(double f)
{
    printf("Time: %5.2f\r",f); fflush(stdout);
}

static void statuslog(int err, const char *msg)
{
    printf("[%-4.4s] %s\n",err ? "ERR" : "INFO", msg);
}


int main(int argc, char *argv[])
{
    int res;

    printf("=== lightscript_init()\n");
    res = lightscript_init();
    printf("--> %d\n",res);

    lightscript_set_status_callback(statuslog);

    printf("=== lightscript_reset()\n");
    res = lightscript_reset();
    printf("--> %d\n",res);

    printf("=== lightscript_tokenize('panel')\n");
    res = lightscript_tokenize_file("panel.cfg");
    printf("--> %d\n",res);

    printf("=== lightscript_tokenize('lightscript')\n");
    res = lightscript_tokenize_file("lightscript.cfg");
    printf("--> %d\n",res);

    printf("=== lightscript_tokenize('sunny')\n");
    res = lightscript_tokenize_file("dancing.ls2");
    printf("--> %d\n",res);

    printf("=== lightscript_parse_script()\n");
    res = lightscript_parse_script();
    printf("--> %d\n",res);

    printf("=== lightscript_set_device('usb')\n");
    res = lightscript_set_device("/dev/cu.usbmodem1301");
    printf("--> %d\n",res);

    printf("=== lightscript_connect()\n");
    res = lightscript_connect();
    printf("--> %d\n",res);

    printf("========================================================================\n");
    
    lightscript_disconnect();

    printf("=== lightscript_reset()\n");
    lightscript_reset();

    printf("=== lightscript_tokenize('panel')\n");
    res = lightscript_tokenize_file("panel.cfg");
    printf("--> %d\n",res);

    printf("=== lightscript_tokenize('lightscript')\n");
    res = lightscript_tokenize_file("lightscript.cfg");
    printf("--> %d\n",res);

    printf("=== lightscript_tokenize('sunny')\n");
    res = lightscript_tokenize_file("dancing.ls2");
    printf("--> %d\n",res);

    printf("=== lightscript_parse_script()\n");
    res = lightscript_parse_script();
    printf("--> %d\n",res);

    printf("=== lightscript_set_device('usb')\n");
    res = lightscript_set_device("/dev/cu.usbmodem1301");
    printf("--> %d\n",res);

    printf("=== lightscript_connect()\n");
    res = lightscript_connect();
    printf("--> %d\n",res);




    
    struct sigaction sigint_action;
    memset(&sigint_action,0,sizeof(sigint_action));
    sigint_action.sa_handler = inthandler;
    sigint_action.sa_flags = 0;
    sigfillset(&sigint_action.sa_mask);
    sigaction(SIGINT, &sigint_action, NULL);

    lightscript_set_time_callback(timecb);
#if 1
    printf("=== lightscript_playback_start()\n");
    res = lightscript_playback_start(1);
    printf("--> %d\n",res);

    lightscript_playback_wait();
#endif

    printf("=== lightscript_disconnect()\n");
    res = lightscript_disconnect();
    printf("--> %d\n",res);

    lightscript_reset();

    return 0;
}

