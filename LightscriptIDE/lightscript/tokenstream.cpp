#include <stdarg.h>

#include <assert.h>

#include "lstokens.h"

#include "tokenstream.hpp"
#include "lsinternal.h"

// tokenstream.cpp
LSToken::LSToken()
    : type(YYEMPTY), fpval(0.0), strval(), filename(), lineno(0) {}

LSToken::LSToken(lstoktype_t tt, const char* fname, int lno, lstoken_t* tok)
    : LSToken()  // proper delegating constructor
{
    type = tt;
    filename = fname ? fname : "";
    lineno = lno;

    switch (tt) {
        case tFLOAT:
            fpval = tok ? tok->f : 0.0;
            break;
        case tIDENT:
        case tSTRING:
            if (tok && tok->str) {
                strval = tok->str;   // copy bytes to std::string
                free(tok->str);      // *** free strdup buffer from lexer ***
                tok->str = nullptr;
            }
            break;
        default:
            break;
    }
}





LSToken::~LSToken()
{

}

/*  *********************************************************************
    *  List of valid tokens
    ********************************************************************* */

typedef struct tokenmap_s {
    lstoktype_t tt;
    const char *str;
} tokenmap_t;

static tokenmap_t tokenNames[] = {
    {YYEOF, "end-of-file"},
    {LBRACKET,"["},
    {RBRACKET,"]"},
    {LBRACE,"{"},
    {RBRACE,"}"},
    {LPAREN,"("},
    {RPAREN,")"},
    {COMMA,","},
    {SEMICOLON,";"},
    {tFLOAT,"floating-point-number"},
    {tIDENT,"identifier"},
    {tSTRING,"string"},
    {tMUSIC,"music"},
    {tFROM,"from"},
    {tTO,"to"},
    {tAT,"at"},
    {tDO,"do"},
    {tON,"on"},
    {tCOUNT,"count"},
    {tIDLE,"idle"},
    {tSPEED,"speed"},
    {tCASCADE,"cascade"},
    {tBRIGHTNESS,"brightness"},
    {tAS,"as"},
    {tMACRO,"macro"},
    {tPALETTE,"palette"},
    {tREVERSE,"reverse"},
    {tCOLOR,"color"},
    {tOPTION,"option"},
    {tDEFMACRO,"defmacro"},
    {tDEFSTRIP,"defstrip"},
    {tDEFANIM,"defanim"},
    {tCOMMENT,"comment"},
    {tPHYSICAL,"physical"},
    {tVIRTUAL,"virtual"},
    {tVSTRIP,"vstrip"},
    {tPSTRIP,"pstrip"},
    {tCHANNEL,"channel"},
    {tTYPE,"type"},
    {tSTART,"start"},
    {tSUBSTRIP,"substrip"},
    {YYEMPTY, NULL}
};


static const char *tokenName(lstoktype_t tt)
{
    tokenmap_t *tm;

    tm = tokenNames;
    while (tm->str) {
        if (tm->tt == tt) {
            return tm->str;
        }
        tm++;
    }

    return "unknown";
}

/*  *********************************************************************
    *  Token Streams
    ********************************************************************* */


LSTokenStream::LSTokenStream()
{

}

LSTokenStream::~LSTokenStream()
{

}

void LSTokenStream::reset()
{
    head = 0;                 // rewind cursor
    tokens.clear();           // destroys tokens; strings free themselves
    tokens.shrink_to_fit();   // give capacity back between runs
}








// tokenstream.cpp
lstoktype_t LSTokenStream::advance() {
    if (head >= tokens.size()) return YYEOF;
    lstoktype_t tt = tokens[head].getType();
    ++head;
    return tt;
}

lstoktype_t LSTokenStream::current() {
    return (head < tokens.size()) ? tokens[head].getType() : YYEOF;
}

int LSTokenStream::currentLine() {
    return (head < tokens.size()) ? tokens[head].getLine() : 0;
}

const char* LSTokenStream::currentFile() {
    return (head < tokens.size()) ? tokens[head].getFileName() : nullptr;
}

bool LSTokenStream::get(LSToken& tok) {
    if (head >= tokens.size()) return false;
    tok = tokens[head];
    return true;
}

void LSTokenStream::add(LSToken& tok) {
    tokens.push_back(tok);
}




bool LSTokenStream::empty() const {
    return head >= tokens.size();
}

const LSToken& LSTokenStream::cur() const {
    // assert or handle EOF as you prefer
    assert(!empty());
    return tokens[head];
}


LSToken& LSTokenStream::cur() {
    assert(!empty());
    return tokens[head];
}




void LSTokenStream::error(const char *str, ...)
{
    char textbuf[512];
    char *p = textbuf;
    
    va_list ap;

    p += snprintf(textbuf,sizeof(textbuf)-1,"[%s:Line %d] ",currentFile(),currentLine());
    va_start(ap,str);
    vsnprintf(p, sizeof(textbuf) - (p - textbuf + 1), str, ap);
    va_end(ap);
    lsprinterr("%s",textbuf);
    errorLine = currentLine();
    throw -1;
}

const char *LSTokenStream::tokenStr(lstoktype_t tt)
{
    return tokenName(tt);
}

const char *LSTokenStream::setStr(lstoktype_t set[])
{
    int i = 0;
    int cnt = 0;

    // See how many are in the set
    while (set[i] != ENDOFLIST) i++;
    cnt = i;

    // Build our string
    errorStr = "";
    if (cnt == 0) return errorStr.c_str();
    
    for (i = 0; i < cnt-1; i++) {
        errorStr += tokenName(set[i]);
        errorStr += ", ";
    }
    errorStr += tokenName(set[i]);

    return errorStr.c_str();
}


void LSTokenStream::match(lstoktype_t tt)
{
    if (current() == tt) {
        advance();
    } else {
        error("Expected '%s' but found '%s'",tokenName(tt),tokenName(current()));
    }
}

//
// Conveneince matchers for things whose values we want to know
//
std::string LSTokenStream::matchIdent(void)
{
    std::string ret;

    if (current() == tIDENT) {
        ret = cur().getString();
        advance();
        return ret;
    } else {
        error("Expected identifier, but found '%s'",tokenName(current()));
    }

    ret = "";
    return ret;
}

std::string LSTokenStream::matchString(void)
{
    std::string ret;

    if (current() == tSTRING) {
        ret = cur().getString();
        advance();
        return ret;
    } else {
        error("Expected string, but found '%s'",tokenName(current()));
    }

    ret = "";
    return ret;
}

int LSTokenStream::matchInt(void)
{
    int ret;
    
    if (current() == tFLOAT) {
        ret = (int) cur().getFloat();
        advance();
        return ret;
    } else {
        error("Expected number but found '%s'",tokenName(current()));
    }
    return 0;
}

double LSTokenStream::matchFloat(void)
{
    double ret;
    
    if (current() == tFLOAT) {
        ret = cur().getFloat();
        advance();
        return ret;
    } else {
        error("Expected floating-point-value but found '%s'",tokenName(current()));
    }
    return 0.0;
}

bool LSTokenStream::predict(lstoktype_t set[])
{
    lstoktype_t cur = current();
    int i = 0;

    while (set[i] != ENDOFLIST) {
        if (cur == set[i]) {
            return true;
        }
        i++;
    }
    return false;
}



