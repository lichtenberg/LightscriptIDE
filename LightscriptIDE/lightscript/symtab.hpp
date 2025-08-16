
#pragma once

#include <string>
#include <vector>

typedef struct LSSymbol_s {
    std::string symName;
    int symValue;
} LSSymbol_t;

class LSSymTab {
public:
    LSSymTab();
    ~LSSymTab();

private:
    std::vector<LSSymbol_t> table;
    std::string tableName;

public:
    bool addSym(std::string name, int value);
    bool findSym(std::string name, int& value) const;
    bool findVal(int value, std::string &name) const;
    bool updateSym(std::string, int value);
    inline unsigned long size() { return table.size(); }
    inline void setName(std::string name) { tableName = name; }
    void reset(void);
};


typedef struct LSStripList_s {
    std::string listName;
    idlist_t *listList;
} LSStripList_t;

class LSStripListTab {
public:
    LSStripListTab();
    ~LSStripListTab();

private:
    std::vector<LSStripList_t> table;

public:
    bool addStripList(std::string name, idlist_t *value);
    bool findStripList(std::string name, idlist_t * &value) const;
    inline unsigned long size() { return table.size(); }
    void reset(void);
};


class LSMacroTab {
public:
    LSMacroTab();
    ~LSMacroTab();

private:
    std::vector<LSMacro_t> table;

public:
    bool addMacro(std::string name, idlist_t *args, cmdlist_t *commands);
    bool findMacro(std::string name, idlist_t * &args, cmdlist_t * &commands) const;
    inline unsigned long size() { return table.size(); }
    void reset(void);
};


