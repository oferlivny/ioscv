//
//  TicToc.h
//  ioscv
//
//  Created by Ofer Livny on 5/9/15.
//  Copyright (c) 2015 Ofer Livny. All rights reserved.
//
#include "TicToc.h"
#include <iostream>
#include <iomanip>

using namespace std;


std::map<std::string, uint64_t> TicToc::timetable;
TicToc::statsmap TicToc::stats;


void TicToc::coutToc(const std::string &tag) {
    cout << setw(10) << left << tag ;
    cout << "Elapsed: ";
    cout << setw(10) << fixed << right << setprecision(0)<< toc(tag)/kToc2ms << "ms" ;
    cout << endl;
}

void TicToc::coutError() {
    cout << "TicToc Error" << endl;
}
double TicToc::toc(const std::string &tag) {
    // first thing is to get the time
    const uint64_t now = mach_absolute_time();
    uint64_t start = timetable[tag];
    timetable.erase(tag);
    
    if (start == 0) return 0.0;
    
    const uint64_t elapsed = now - start;
    
    mach_timebase_info_data_t info;
    if (mach_timebase_info(&info)) {
        coutError();
        return 0.0;
    }
    // Get elapsed time in nanoseconds:
    const double elapsedNS = (double)elapsed * (double)info.numer / (double)info.denom;
    store(tag,elapsedNS);
    return elapsedNS;
}

void TicToc::store(const std::string &tag, double elapsed) {
    stats_ &s = stats[tag];
    if (s.count == 0) {
        s.max = elapsed;
        s.min = elapsed;
    } else {
        s.min = s.min < elapsed ? s.min : elapsed;
        s.max = s.max < elapsed ? elapsed : s.max;
    }
    
    s.sum += elapsed;
    s.count++;
}

void TicToc::coutStats() {
    cout << "Stats:" << endl;
    TicToc::statsmap::const_iterator iter;
    for (iter=stats.begin(); iter != stats.end() ; iter++) {
        cout << setw(10) << left << iter->first;
        cout << ": ";
        cout << fixed << setprecision(0) << right << setw(6) << iter->second.sum / (iter->second.count * kToc2ms);
        cout << " ( " ;
        cout << fixed << setprecision(0) << right << setw(6) << iter->second.min / kToc2ms;
        cout << " - ";
        cout << fixed << setprecision(0) << right << setw(6) << iter->second.max / kToc2ms;
        cout << " )" << endl;
    }
}
