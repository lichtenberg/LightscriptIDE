/*  *********************************************************************
    *  LightScript - A script processor for LED animations
    *  
    *  Tokenizer (LEX/FLEX) script              file: lightscript.lex
    *  
    *  defines the tokens used by the parser.
    *  
    *  Author:  Mitch Lichtenberg
    ********************************************************************* */

%option noyywrap yylineno
%option header-file="ls_lexer.h"

%{
#include "lstokens.h"
#define YY_NO_INPUT
#define YY_NO_UNPUT

static char *unquote(char *str) {
    char *x = strchr(str+1,'"');
    if (x) *x = '\0';
    // XXX this leaks.  Do we really need to duplicate this here?
    return strdup(str+1);
}
static inline double parsetime(char *str) {
    double minutes = 0;
    double seconds = 0;
    char *colon = strchr(str,':');
    if (colon) {
        *colon++ = '\0';
        if (*str != ':') minutes = atof(str);
        seconds = atof(colon);
    } else {
        seconds = atof(str);
    }
    seconds = minutes*60.0 + seconds;
    return seconds;
}

extern lstoken_t yylval;

%}

digit     [0-9]
letter    [A-Za-z]
whitespace [ ]
hexdigit  [0-9A-Fa-f]

%%

"music"         return tMUSIC;
"from"          return tFROM;
"to"            return tTO;
"at"            return tAT;
"do"            return tDO;
"on"            return tON;
"count"         return tCOUNT;
"idle"          return tIDLE;
"speed"         return tSPEED;
"cascade"       return tCASCADE;
"delay"         return tDELAY;
"brightness"    return tBRIGHTNESS;
"define"        return tDEFINE;
"defmacro"      return tDEFMACRO;
"macro"         return tMACRO;
"as"            return tAS;
"palette"       return tPALETTE;
"color"         return tCOLOR;
"option"        return tOPTION;
"reverse"       return tREVERSE;
"defstrip"      return tDEFSTRIP;
"defanim"       return tDEFANIM;
"defcolor"      return tDEFCOLOR;
"defpalette"    return tDEFPALETTE;
"direction"     return tDIRECTION;
"comment"       return tCOMMENT;
"physical"      return tPHYSICAL;
"virtual"       return tVIRTUAL;
"pstrip"        return tPSTRIP;
"vstrip"        return tVSTRIP;
"channel"       return tCHANNEL;
"type"          return tTYPE;
"start"         return tSTART;
"substrip"      return tSUBSTRIP;
"{"             return '{';
"}"             return '}';
"["             return '[';
"]"             return ']';
"("             return '(';
")"             return ')';
\;              return ';';
\,              return ',';
"="             return tAS;

{letter}({digit}|{letter}|_)*      {
    yylval.str = strdup(yytext);
    return tIDENT;
    }
-?{digit}+\.{digit}*               { yylval.f    = atof(yytext); return tFLOAT; }
-?{digit}+\:{digit}+\.{digit}+     { yylval.f    = parsetime(yytext); return tFLOAT; }
{digit}+                           { yylval.f    = (double) atoi(yytext); return tFLOAT; }
\".*\"                             { yylval.str = unquote(yytext); return tSTRING; }
0x{hexdigit}+                      { yylval.f    = (double) strtol(yytext,NULL,0); return tFLOAT; }
\/\/.*$                            { }
\n                                 { }

%%



