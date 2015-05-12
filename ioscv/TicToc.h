//
//  TicToc.h
//  ioscv
//
//  Created by Ofer Livny on 5/9/15.
//  Copyright (c) 2015 Ofer Livny. All rights reserved.
//

#ifndef _tictoc_h_
#define _tictoc_h_

#include <unistd.h>
#include <string>
#include <mach/mach_time.h>
#include <map>
class TicToc {
public:
    typedef struct stats {
        double sum;
        uint64_t count;
        double min;
        double max;
    } Stats;
    typedef std::map<std::string, Stats> statsmap;

private:
    static statsmap stats;
    static std::map<std::string, uint64_t> timetable;
    static const uint64_t kToc2ms = 1e6;
    
    static void coutError();
    static void store(const std::string &tag, double elapsed);
public:
    static inline void tic(const std::string &tag) {
        uint64_t &t = timetable[tag];
        t = mach_absolute_time();
    }
    static double toc(const std::string &tag);
    static void coutToc(const std::string &tag);
    static void coutStats();
    static void clearStats() {stats.clear();}
    static Stats getStatsForTag(const std::string &tag);
};

class TICTOC {
    std::string tag;
    bool print;
public:
    TICTOC(const std::string &t, bool p = false):tag(t), print(p) {
        TicToc::tic(tag);
    }
    ~TICTOC() {
        if (print)
            TicToc::coutToc(tag);
        else
            TicToc::toc(tag);
    }
};
#endif