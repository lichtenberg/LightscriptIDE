
#include <string>
#include <vector>

#include "lsinternal.h"
#include "symtab.hpp"


LSSymTab::LSSymTab()
{
    tableName = "not_set";
}


LSSymTab::~LSSymTab()
{

}

void LSSymTab::reset(void)
{
    table.clear();
}

bool LSSymTab::updateSym(std::string name, int value)
{
    std::vector<LSSymbol_t>::iterator i;
    LSSymbol_t sym;
    
    for (i = table.begin(); i != table.end(); i++) {
        if (i->symName == name) {
            i->symValue = value;
            return true;
        }
    }

    sym.symName = name;
    sym.symValue = value;

    table.push_back(sym);

    return false;
}

bool LSSymTab::addSym(std::string name, int value)
{
    int x;
    LSSymbol_t sym;

    if (findSym(name, x) == true) {
        return false;
    }

    sym.symName = name;
    sym.symValue = value;

//    printf("[%s] : Added '%s' val %d\n",tableName.c_str(), name.c_str(), value);

    table.push_back(sym);

    return true;
}

bool LSSymTab::findVal(int value, std::string &name) const
{
    for (auto i = table.begin(); i != table.end(); i++) {
        if (i->symValue == value) {
            name = i->symName;
            return true;
        }
    }
    return false;
}

bool LSSymTab::findSym(std::string name, int& value) const
{
    for (auto i = table.begin(); i != table.end(); i++) {
        if (i->symName == name) {
            value = i->symValue;
            return true;
        }
    }
    return false;
}





LSStripListTab::LSStripListTab()
{

}


LSStripListTab::~LSStripListTab()
{

}

void LSStripListTab::reset(void)
{
    table.clear();
}


bool LSStripListTab::addStripList(std::string name, idlist_t *idlist)
{
    LSStripList_t list;
    idlist_t *x;

    if (findStripList(name, x) == true) {
        return false;
    }

    list.listName = name;
    list.listList = idlist;

//    printf("[%s] : Added '%s'\n","striplist", name.c_str());

    table.push_back(list);

    return true;
}

bool LSStripListTab::findStripList(std::string name, idlist_t * &value) const
{
//    std::vector<LSStripList_t>::iterator i;
    
    for (auto i = table.begin(); i != table.end(); i++) {
        if (i->listName == name) {
            value = i->listList;
            return true;
        }
    }
    return false;
}





LSMacroTab::LSMacroTab()
{

}


LSMacroTab::~LSMacroTab()
{

}

void LSMacroTab::reset(void)
{
    table.clear();
}

bool LSMacroTab::addMacro(std::string name, idlist_t *idlist, cmdlist_t *commands)
{
    LSMacro_t macro;
    idlist_t * idlx;
    cmdlist_t *cmdlx;
    
    if (findMacro(name, idlx, cmdlx) == true) {
        return false;
    }

    macro.name = name;
    macro.args = idlist;
    macro.commands = commands;

//    printf("Added macro '%s' with %ld commands\n",name.c_str(), commands->size());

    table.push_back(macro);

    return true;
}

bool LSMacroTab::findMacro(std::string name, idlist_t * &args, cmdlist_t * &commands) const
{
    for (auto i = table.begin(); i != table.end(); i++) {
        if (i->name == name) {
            args = i->args;
            commands = i->commands;
            return true;
        }
    }
    return false;
}





