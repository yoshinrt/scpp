#ifndef _COMMON_H
#define _COMMON_H
#include <systemc.h>

#ifdef VCD_WAVE
extern sc_trace_file *trace_f;
#endif

#define	REG_SRCADDR	0
#define	REG_DSTADDR	1
#define REG_CNT		2
#define REG_CTRL	3

#endif
