
#pragma once

typedef enum {
    YYEMPTY = -2,
    YYEOF = 0,                     /* "end of file"  */

    // Make enums for some of our character tokens to keep compiler happy
    LBRACKET = '[',
    RBRACKET = ']',
    LBRACE = '{',
    RBRACE = '}',
    LPAREN = '(',
    RPAREN = ')',
    COMMA = ',',
    SEMICOLON = ';',

    YYerror = 256,                 /* error  */
    YYUNDEF = 257,                 /* "invalid token"  */
    tFLOAT = 258,                  /* tFLOAT  */
    tIDENT = 260,                  /* tIDENT  */
    tSTRING = 261,                 /* tSTRING  */
    tMUSIC = 262,                  /* tMUSIC  */
    tFROM = 263,                   /* tFROM  */
    tTO = 264,                     /* tTO  */
    tAT = 265,                     /* tAT  */
    tDO = 266,                     /* tDO  */
    tON = 267,                     /* tON  */
    tCOUNT = 268,                  /* tCOUNT  */
    tIDLE = 269,                   /* tIDLE  */
    tSPEED = 270,                  /* tSPEED  */
    tCASCADE = 271,                /* tCASCADE  */
    tDELAY = 272,                  /* tDELAY  */
    tBRIGHTNESS = 273,             /* tBRIGHTNESS  */
    tDEFINE = 274,                 /* tDEFINE  */
    tAS = 275,                     /* tAS  */
    tMACRO = 276,                  /* tMACRO  */
    tPALETTE = 277,                /* tPALETTE  */
    tREVERSE = 278,                /* tREVERSE  */
    tCOLOR = 279,                  /* tCOLOR  */
    tOPTION = 280,                 /* tOPTION  */
    tDEFMACRO = 281,               /* tDEFMACRO */
    tDEFSTRIP = 282,
    tDEFANIM = 283,
    tDEFCOLOR = 284,
    tDEFPALETTE = 285,
    tDIRECTION = 286,
    tCOMMENT = 287,
    tPHYSICAL = 288,
    tVIRTUAL = 289,
    tVSTRIP = 290,
    tPSTRIP = 291,
    tCHANNEL = 292,
    tTYPE = 293,
    tSTART = 294,
    tSUBSTRIP = 295,
} lstoktype_t;

#define CHARTOKEN(x) ((lstoktype_t) (x))
#define ENDOFLIST ((lstoktype_t) YYEMPTY)


typedef struct lstoken_s {
    double f;
    char *str;
} lstoken_t;

