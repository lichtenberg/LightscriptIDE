#pragma once

#include "tokenstream.hpp"
#include "lsinternal.h"


class LSParser {
public:
    LSParser();
    LSParser(LSTokenStream *stream, LSScript *script);
    ~LSParser();

private:
    LSTokenStream *tokenStream;
    LSScript *script;

public:
    int parse();
    void init(LSTokenStream *ts, LSScript *ls);
    void parseTopLevel();
    int currentLine(void);
    
private:
    std::unique_ptr<LSCommand_t> parseScriptCmd();
    idlist_t *parseIDList();
    idlist_t *parseIDSingle();
    idlist_t *parseArgList();
    vallist_t *parseValueList();
    void parseOption(LSCommand_t& cmd);
    void parseOptionList(LSCommand_t& cmd);
    void parseMacroBody(idlist_t * &idl, cmdlist_t * &cmdl);
    void parsePhysicalStrips(void);
    void parseVirtualStrips(void);
    void parseOnePhysicalStrip(void);
    void parseOneVirtualStrip(void);
    unsigned int parseOneSubstrip(void);
    PStrip_t *findPStrip(std::string& name);
};
