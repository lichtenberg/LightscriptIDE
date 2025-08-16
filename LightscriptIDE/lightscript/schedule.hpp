

#include "parser.hpp"
#include <memory>
#include <string>
#include <vector>


typedef struct schedcmd_s {
    double time;
    std::string comment;
    int line;
    uint32_t stripmask[MAXVSTRIPS/32];
    int animation;
    int speed;
    int brightness;
    int palette;
    int direction;
    int option;
} schedcmd_t;



typedef std::vector<std::unique_ptr<schedcmd_t>> schedule_t;

class LSSchedule {
public:
    LSSchedule();
    ~LSSchedule();
public:
    void stripMask(LSCommand_t *c, idlist_t *list, uint32_t *mask);

private:
    int nestLevel;

private:
    void insert(double baseTime, LSCommand_t *c);
    void insert_do(double baseTime, LSCommand_t *c);
    void insert_comment(double baseTime, LSCommand_t *c);
    void insert_cascade(double baseTime, LSCommand_t *c);
    void insert_macro(double baseTime, LSCommand_t *c);
    std::unique_ptr<schedcmd_t> newSchedCmd(double baseTime, LSCommand_t *cmd);
    void setAnimation(LSCommand_t *cmd, schedcmd_t& scmd);
    void setColor(LSCommand_t *cmd, schedcmd_t& scmd);
    void stripVec1(LSCommand_t *c, std::vector<int> *vec, idlist_t *list);
    std::vector<int> *stripVec(LSCommand_t *c, idlist_t *list);

    void addSched(std::unique_ptr<schedcmd_t> scmd);

    int findStrip(std::string name);

    schedule_t schedule;
    const LSScript* script = nullptr;

    bool generate1(void);

public:
    bool generate(const LSScript& theScript);
    void printSched(void);
    void printSchedEntry(const schedcmd_t *scmd);
    int size(void);
    schedcmd_t *getAt(int i);
    void reset(void);

};
