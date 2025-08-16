#include <vector>
#include <string>
#include "lsinternal.h"
#include "parser.hpp"
#include "symtab.hpp"



LSParser::LSParser()
{

}

LSParser::~LSParser()
{

}

LSParser::LSParser(LSTokenStream *stream, LSScript *scr)
{
    LSParser();
    tokenStream = stream;
    script = scr;
}

void LSParser::init(LSTokenStream *stream, LSScript *scr)
{
    tokenStream = stream;
    script = scr;
}

int LSParser::parse(void)
{
    int ret = 0;

    try {
        parseTopLevel();
    } catch (int e) {
        ret = e;
    }

    return ret;
}


idlist_t *LSParser::parseIDList(void)
{
    idlist_t *idlist;

    idlist = new idlist_t;

    tokenStream->match(CHARTOKEN('['));

    while (tokenStream->current() != CHARTOKEN(']')) {
        idlist->push_back(tokenStream->matchIdent());
        if (tokenStream->current() == CHARTOKEN(',')) {
            tokenStream->advance();
            continue;
        } else {
            // Drop down to either match our bracket or die.
            break;
        }
    }

    tokenStream->match(CHARTOKEN(']'));

    return idlist;
}

idlist_t *LSParser::parseIDSingle(void)
{
    idlist_t *idlist;

    idlist = new idlist_t;

    idlist->push_back(tokenStream->matchIdent());

    return idlist;
}


idlist_t *LSParser::parseArgList(void)
{
    idlist_t *idlist;

    idlist = new idlist_t;
    
    tokenStream->match(CHARTOKEN('('));

    while (tokenStream->current() != CHARTOKEN(')')) {
        idlist->push_back(tokenStream->matchIdent());
        if (tokenStream->current() == CHARTOKEN(',')) {
            tokenStream->advance();
            continue;
        } else {
            // Drop down to either match our bracket or die.
            break;
        }
    }

    tokenStream->match(CHARTOKEN(')'));
    return idlist;
}

vallist_t *LSParser::parseValueList(void)
{
    vallist_t *vallist;

    vallist = new vallist_t;
    
    tokenStream->match(CHARTOKEN('('));

    while (tokenStream->current() != CHARTOKEN(')')) {
        vallist->push_back(tokenStream->matchFloat());
        if (tokenStream->current() == CHARTOKEN(',')) {
            tokenStream->advance();
            continue;
        } else {
            // Drop down to either match our bracket or die.
            break;
        }
    }

    tokenStream->match(CHARTOKEN(')'));
    return vallist;
}

void LSParser::parseMacroBody(idlist_t * &idl, cmdlist_t * &cmdl)
{
    cmdlist_t *cmdlist;
    idlist_t *idlist = NULL;
    
    // If the macro has an arglist, parse it.
    if (tokenStream->current() == CHARTOKEN('(')) {
        idl = parseArgList();
    }
    
    tokenStream->match(CHARTOKEN('{'));

    cmdlist = new cmdlist_t;

    while (tokenStream->current() != CHARTOKEN('}')) {
        cmdlist->push_back(parseScriptCmd());
    }
    tokenStream->match(CHARTOKEN('}'));

    cmdl = cmdlist;
    idl = idlist;
}

void LSParser::parseOption(LSCommand_t& cmd)
{
    lstoktype_t terminals[] = {
        tON,
        tCASCADE,
        tDO,
        tMACRO,
        tBRIGHTNESS,
        tDELAY,
        tSPEED,
        tCOUNT,
        tOPTION,
        tPALETTE,
        tCOLOR,
        tREVERSE,
        tDIRECTION,
        tCOMMENT,
        ENDOFLIST};

    lstoktype_t tt;

    // Check our terminals
    if (tokenStream->predict(terminals) == false) {
        tokenStream->error("Expected option name (%s) but found '%s'",tokenStream->setStr(terminals), tokenStream->tokenStr(tokenStream->current()));
    }

    // Ok, consume the token but remember its type
    tt = tokenStream->advance();

    // Act on the terminal.
    switch (tt) {
        case tON:
            if (tokenStream->current() == tIDENT) {
                // Just a single identifier
                cmd.lsc_strips.reset(parseIDSingle());
            } else {
                // list of identifiers.
                cmd.lsc_strips.reset(parseIDList());
            }
            break;
        case tCASCADE:
            cmd.lsc_type = LSC_CASCADE;
            cmd.lsc_animation = tokenStream->matchIdent();
            break;
        case tDO:
            cmd.lsc_type = LSC_DO;
            cmd.lsc_animation = tokenStream->matchIdent();
            break;
        case tCOMMENT:
            cmd.lsc_type = LSC_COMMENT;
            cmd.lsc_comment = tokenStream->matchString();
            break;
        case tMACRO:
            cmd.lsc_type = LSC_MACRO;
            cmd.lsc_macro = tokenStream->matchIdent();
            if (tokenStream->current() == CHARTOKEN('(')) {
                // Parse arguments here
                cmd.lsc_macroArgs.reset(parseValueList());
            }
            break;
        case tBRIGHTNESS:
            cmd.opt_brightness = tokenStream->matchInt();
            break;
        case tDELAY:
            cmd.opt_delay = tokenStream->matchFloat();
            break;
        case tSPEED:
            cmd.opt_speed = tokenStream->matchInt();
            break;
        case tCOUNT:
            cmd.opt_count = tokenStream->matchInt();
            break;
        case tOPTION:
            cmd.opt_option = tokenStream->matchInt();
            break;
        case tPALETTE:
            if (tokenStream->current() == tFLOAT) {
                cmd.opt_color = tokenStream->matchInt();
                cmd.opt_colorIdent = "";
            } else {
                cmd.opt_colorIdent = tokenStream->matchIdent();
            }
            break;
        case tCOLOR:
            if (tokenStream->current() == tFLOAT) {
                cmd.opt_color = tokenStream->matchInt() | COLORFLG;
                cmd.opt_colorIdent = "";
            } else {
                cmd.opt_colorIdent = tokenStream->matchIdent();
            }
            break;
        case tREVERSE:
            cmd.opt_reverse = true;
            break;
        case tDIRECTION:
            // This is a different way to specify the directiont that can be parameterized
            {
                int dir = tokenStream->matchInt();
                cmd.opt_reverse = (dir) < 0 ? true : false;
            }
            break;
        default:
            break;
    }

}

void LSParser::parseOptionList(LSCommand_t& cmd)
{
    while (tokenStream->current() != CHARTOKEN(';')) {
        parseOption(cmd);
    }
}


std::unique_ptr<LSCommand_t> LSParser::parseScriptCmd()
{
    lstoktype_t terminals[] = {
        tAT,
        tFROM,
        tMUSIC,
        tIDLE,
        tDEFINE,
        tDEFMACRO,
        tDEFANIM,
        tDEFSTRIP,
        tDEFCOLOR,
        tDEFPALETTE,
        tPHYSICAL,
        tVIRTUAL,
        ENDOFLIST};
    lstoktype_t tt;
    bool save = false;

    std::string id;
    int v;

    std::unique_ptr<LSCommand_t> cmd;

    // Allocate a command.
    cmd = std::make_unique<LSCommand_t>();

    cmd->opt_color = 0x40;              // Default to RGB palette unless overridden

    // Remmeber about where the script command was.
    cmd->lsc_line = tokenStream->currentLine();

    // Check our terminals
    if (tokenStream->predict(terminals) == false) {
        tokenStream->error("Expected script command");
    }

    // Ok, consume the token but remember its type
    tt = tokenStream->advance();

    // Act on the terminal.
    switch (tt) {
        case tAT:
            cmd->lsc_type = LSC_DO;
            cmd->lsc_from = tokenStream->matchFloat();
            cmd->lsc_to = cmd->lsc_from;
            parseOptionList(*cmd);
            cmd->lsc_count = 1;
            save = true;
            break;
        case tFROM:
            cmd->lsc_type = LSC_DO;
            cmd->lsc_from = tokenStream->matchFloat();
            tokenStream->match(tTO);
            cmd->lsc_to = tokenStream->matchFloat();
            parseOptionList(*cmd);
            cmd->lsc_count = cmd->opt_count;
            save = true;
            break;
        case tMUSIC:
            script->lss_music = tokenStream->matchString();
            break;
        case tIDLE:
            script->lss_idleanimation = tokenStream->matchIdent();
            parseOptionList(*cmd);
            script->lss_idlestrips = std::move(cmd->lsc_strips);
            cmd->lsc_strips.reset();
            break;
        case tDEFSTRIP:
            id = tokenStream->matchIdent();
            tokenStream->match(tAS);

            switch (tokenStream->current()) {
                case CHARTOKEN('['):
                    // strip list
                    script->stripListTable.addStripList(id,parseIDList());
                    break;
                default:
                    // Single strip number (not allowed anymore)
                    tokenStream->error("Expected '[' to start a list of strip names, but found %s",tokenStream->tokenStr(tokenStream->current()));
                    break;
            }
            break;
        case tDEFINE:
            id = tokenStream->matchIdent();
            tokenStream->match(tAS);
            v = tokenStream->matchInt();
            script->symbolTable.addSym(id,v);
            break;
        case tDEFANIM:
            id = tokenStream->matchIdent();
            tokenStream->match(tAS);
            v = tokenStream->matchInt();
            script->animTable.addSym(id,v);
            break;
        case tDEFCOLOR:
        case tDEFPALETTE:
            id = tokenStream->matchIdent();
            tokenStream->match(tAS);
            v = tokenStream->matchInt();
            if (tt == tDEFCOLOR) v |= COLORFLG;
            script->colorTable.addSym(id,v);
            break;
        case tDEFMACRO:
            id = tokenStream->matchIdent();
            idlist_t *idlist;
            cmdlist_t *cmdlist;
            parseMacroBody(idlist,cmdlist);
            script->macroTable.addMacro(id, idlist, cmdlist);
            break;

        case tPHYSICAL:
            parsePhysicalStrips();
            break;
            
        case tVIRTUAL:
            parseVirtualStrips();
            break;

        default:
            tokenStream->error("Should not happen");
            break;
    }

    // Commands end in semicolons.
    tokenStream->match(CHARTOKEN(';'));

    if (!save) {
        cmd.reset();
    }

    return cmd;
}

static int channelNameToNum(std::string& idstr)
{
    const char *str = idstr.c_str();
    int port = -1;
    int chan = -1;

    // It's a PICOLASER channel
    if ((str[0] == 'l') || (str[0] == 'L') || (str[0] == 'S') || (str[0] == 's')) {
        if ((str[0] == 'l') || (str[0] == 'L')) {
            chan = str[1] - '0';
            return chan;
        }
        if ((str[0] == 's') || (str[0] == 'S')) {
            chan = 10 + (str[1] - '0');
            if (chan > 11) chan = 11;
            return chan;
        }
    }

    if ((str[0] == 'a') || (str[0] == 'A')) port = 0;
    if ((str[0] == 'b') || (str[0] == 'B')) port = 1;
    if ((str[1] >= '1') && (str[1] <= '8')) chan = str[1] - '1';

    if ((port < 0) || (chan < 0)) {
        return -1;
    }

    return (port * 8) + chan;
}


void LSParser::parseOnePhysicalStrip(void)
{
    lstoktype_t terminals[] = {
        tCHANNEL,
        tTYPE,
        tCOUNT,
        ENDOFLIST};
    lstoktype_t tt;
    int physChannel = -1;
    int physChanType = 0;               // need enums for RGB, GBR, ...
    int physCount = -1;
    std::string physStripName;
    std::string idstr;
    
    tokenStream->match(tPSTRIP);

    physStripName = tokenStream->matchIdent();

    while (tokenStream->current() != CHARTOKEN(';')) {
        if (tokenStream->predict(terminals) == false) {
            tokenStream->error("Physical strip %s: Expected strip attribute (%s) but found '%s'",
                               physStripName.c_str(),
                               tokenStream->setStr(terminals), tokenStream->tokenStr(tokenStream->current()));

        }
        tt = tokenStream->advance();

        switch (tt) {
            case tCHANNEL:
                idstr = tokenStream->matchIdent();
                physChannel = channelNameToNum(idstr);
                if (physChannel < 0) {
                    tokenStream->error("Physical strip %s: Invalid channel name specified: %s, must be A1..A8 or B1..B8",
                                       physStripName.c_str(), idstr.c_str());
                }
                break;
            case tTYPE:
                idstr = tokenStream->matchIdent();
                if (strcmp(idstr.c_str(),"LASER") == 0) {
                    physChanType = PSTRIP_TYPE_LASER;
                } else if (strcmp(idstr.c_str(),"RGB") == 0) {
                    physChanType = PSTRIP_TYPE_RGB;
                } else if (strcmp(idstr.c_str(),"GRB") == 0) {
                    physChanType = PSTRIP_TYPE_GRB;
                } else {
                    tokenStream->error("Physical strip type '%s' not valid, choose RGB, GRB or LASER",idstr.c_str());
                }
                break;
            case tCOUNT:
                physCount = tokenStream->matchInt();
                break;
            default:
                tokenStream->error("Should not happen");
                break;
        }
    }

    tokenStream->match(CHARTOKEN(';'));

    if (physCount < 0) {
        tokenStream->error("Physical strip %s: Numnber of LEDs for strip was not specified", physStripName.c_str());
    }
    if (physChanType < 0) {
        tokenStream->error("Physical strip %s: Strip type was not specified", physStripName.c_str());
    }
    if (physChannel < 0) {
        tokenStream->error("Physical strip %s: channel ID was not specified", physStripName.c_str());
    }


    unsigned int encodedStrip = ENCODEPSTRIP(physChannel, physChanType, physCount);

    // Add this to the physical strip table.
    script->physicalStrips[physChannel].info = encodedStrip;
    script->physicalStrips[physChannel].name = physStripName;
}

PStrip_t * LSParser::findPStrip(std::string& name)
{
    int idx;

    for (idx = 0; idx < MAXPSTRIPS; idx++) {
        if (script->physicalStrips[idx].name == name) {
            return &(script->physicalStrips[idx]);
        }
    }
    return NULL;
}


unsigned int LSParser::parseOneSubstrip(void)
{
    lstoktype_t terminals[] = {
        tSTART,
        tCOUNT,
        tREVERSE,
        ENDOFLIST};
    lstoktype_t tt;
    std::string idstr;
    int subStart = -1;
    int subCount = -1;
    int subFlags = 0;
    PStrip_t *pstrip;

    tokenStream->match(tSUBSTRIP);
    idstr = tokenStream->matchIdent();

    while (tokenStream->current() != CHARTOKEN(';')) {
        if (tokenStream->predict(terminals) == false) {
            tokenStream->error("Expected substrip attribute (%s) but found '%s'",tokenStream->setStr(terminals), tokenStream->tokenStr(tokenStream->current()));
        }

        tt = tokenStream->advance();

        switch (tt) {
            case tSTART:
                subStart = tokenStream->matchInt();
                break;
            case tCOUNT:
                subCount = tokenStream->matchInt();
                break;
            case tREVERSE:
                subFlags |= SUBSTRIP_REVERSE;
                break;
            default:
                tokenStream->error("Should not happen");
                break;
        }
        
    }

    tokenStream->match(CHARTOKEN(';'));


    pstrip = findPStrip(idstr);
    if (pstrip == NULL) {
        tokenStream->error("Substrip: Invalid physical strip %s",idstr.c_str());
    }

    // If the start is not specified, it's assumed to be zero (the beginning of the physical strip)
    if (subStart < 0) {
        subStart = 0;
    }
    // If the length is not specified, it's assumed to be the length of the physical strip
    if (subCount < 0) {
        subCount = PSTRIP_COUNT(pstrip->info);
    }

    unsigned int encodedSubstrip =
        ENCODESUBSTRIP(PSTRIP_CHAN(pstrip->info), subStart, subCount, subFlags);

    return encodedSubstrip;

}

void LSParser::parseOneVirtualStrip(void)
{
    uint32_t encodedSubstrip;
    VStrip_t *vstrip;

    if (script->virtualStripCount >= MAXVSTRIPS) {
        tokenStream->error("Maximium number of virtual strips have been defined (%u)", MAXVSTRIPS);
    }

    vstrip = &(script->virtualStrips[script->virtualStripCount]);
    script->virtualStripCount++;
    
    tokenStream->match(tVSTRIP);

    vstrip->name = tokenStream->matchIdent();

    tokenStream->match(CHARTOKEN('{'));

    // Grab all the sub strips
    while (tokenStream->current() != CHARTOKEN('}')) {
        encodedSubstrip = parseOneSubstrip();
        if (vstrip->substripCount >= MAXSUBSTRIPS) {
            tokenStream->error("Maximium number of substrips for %s have been defined (%u)", vstrip->name.c_str(),MAXVSTRIPS);
        }
        vstrip->substrips[vstrip->substripCount] = encodedSubstrip;
        vstrip->substripCount++;
    }

    tokenStream->match(CHARTOKEN('}'));
    tokenStream->match(CHARTOKEN(';'));

}

void LSParser::parsePhysicalStrips(void)
{
    tokenStream->match(CHARTOKEN('{'));

    while (tokenStream->current() != CHARTOKEN('}')) {
        parseOnePhysicalStrip();
    }

    tokenStream->match(CHARTOKEN('}'));
}

void LSParser::parseVirtualStrips(void)
{
    tokenStream->match(CHARTOKEN('{'));

    while (tokenStream->current() != CHARTOKEN('}')) {
        parseOneVirtualStrip();
    }

    tokenStream->match(CHARTOKEN('}'));
    
}

void LSParser::parseTopLevel()
{
    std::unique_ptr<LSCommand_t> cmd;
    
    while (tokenStream->current() != YYEOF) {
        cmd = parseScriptCmd();
        if (cmd) {
            script->lss_commands.push_back(std::move(cmd));
        }
    }
}

int LSParser::currentLine(void)
{
    return 0;
}
