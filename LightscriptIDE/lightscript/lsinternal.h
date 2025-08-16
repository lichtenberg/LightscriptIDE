/*  *********************************************************************
    *  LightScript - A script processor for LED animations
    *  
    *  Data structures                          File: lightscript.h
    *  
    *  Our common include file, structures, constants, enums etc.
    *  
    *  Author:  Mitch Lichtenberg
    ********************************************************************* */


#pragma once
#include <memory>

/*
 * lightscript stuff
 */

//#define MAXPSTRIPS      16              // Total physical strips
//#define MAXVSTRIPS      128             // Total virtual strips 
//#define MAXSUBSTRIPS    8               // Substrips per virtual strip

typedef enum {
    LSC_UNKNOWN = 0,
    LSC_CASCADE = 1,
    LSC_DO = 2,
    LSC_MACRO = 3,
    LSC_COMMENT = 4
} lsctype_t;

#define COLORFLG  0x1000000
typedef std::vector<std::string> idlist_t;
typedef std::vector<double> vallist_t;

#include "picoprotocol.h"

typedef struct LSCommand_s {
    // Command type:
    lsctype_t lsc_type;

    // Where the command is in the file
    int lsc_line;

    // Time index (could be relative) of where the command starts.
    double lsc_from;
    double lsc_to;
    int lsc_count;

    // Macro name (if it's a macro call)
    std::string lsc_macro;
    std::unique_ptr<vallist_t> lsc_macroArgs;

    std::string lsc_comment;
    // Animation
    std::string lsc_animation;
    // Strip list
    std::unique_ptr<idlist_t> lsc_strips;


    // Options
    double opt_delay;
    int opt_speed;
    int opt_count;
    int opt_option;
//    int opt_palette;
//    std::string opt_paletteIdent;
    int opt_brightness;
    int opt_color;
    std::string opt_colorIdent;
    bool opt_reverse;
    
} LSCommand_t;
typedef std::vector<std::unique_ptr<LSCommand_t>> cmdlist_t;
typedef std::vector<int> stripvec_t;


typedef struct LSMacro_s {
    std::string name;
    idlist_t *args;
    cmdlist_t *commands;
} LSMacro_t;

#include "symtab.hpp"


typedef struct PStrip_s {
    std::string name;
    unsigned int idx;
    uint32_t info;
} PStrip_t;

typedef struct VStrip_s {
    std::string name;
    unsigned int idx;
    int substripCount;
    uint32_t substrips[MAXSUBSTRIPS+1];         // Leave one for the sentinel
} VStrip_t;


class LSScript {
public:
    // Global stuff about the script
    std::string lss_idleanimation;
    std::unique_ptr<idlist_t> lss_idlestrips;
    std::string lss_music;

    // Set of script commands
    cmdlist_t lss_commands;

    // Start/Stop cues
    double lss_startcue = 0;
    double lss_endcue = 0;

    // Symbol tables
    LSSymTab symbolTable;
    LSSymTab animTable;
    LSSymTab colorTable;
    LSStripListTab stripListTable;
    LSMacroTab macroTable;

    // No need for symbol tables for these because they are fixed in size by the firmware.
    // Physical Strips.
    PStrip_t physicalStrips[MAXPSTRIPS] = {};
    // Virtual Strips
    int virtualStripCount = 0;
    VStrip_t virtualStrips[MAXVSTRIPS] = {};

    void reset() {
        symbolTable.reset();
        animTable.reset();
        colorTable.reset();
        stripListTable.reset();
        macroTable.reset();
        for (auto i = 0; i < MAXPSTRIPS; i++) {
            physicalStrips[i].name.clear();
            physicalStrips[i].idx = 0;
            physicalStrips[i].info = 0;
        }
        for (auto i = 0; i < MAXVSTRIPS; i++) {
            virtualStrips[i].name.clear();
            virtualStrips[i].idx = 0;
            virtualStrips[i].substripCount = 0;
            memset(virtualStrips[i].substrips,0,sizeof(virtualStrips[i].substrips));
        }
        lss_startcue = 0;
        lss_endcue = 0;
        virtualStripCount = 0;
        if (lss_idlestrips.get() != nullptr) lss_idlestrips.get()->clear();
        lss_music.clear();
        lss_idleanimation.clear();
        lss_commands.clear();
    }
};

extern "C" {
    int lsprintf(const char * str, ...);
    int lsprinterr(const char * str,...);
};
