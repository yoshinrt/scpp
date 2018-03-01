CC = g++ -O2

PROGRAM = sc
ARCH    = cygwin
SYSTEMC = /home/yoshi/systemc-2.3.1a

INCDIR = -I. \
         -I$(SYSTEMC)/include/
LIBDIR = -L$(SYSTEMC)/lib-$(ARCH)/
LIBS   = -lsystemc -lm 

SRCS = sc.cpp
OBJS = $(SRCS:.cpp=.o)
HEADERS = sig_trace.h

all: $(PROGRAM)
	SYSTEMC_DISABLE_COPYRIGHT_MESSAGE=1 ./$(PROGRAM)

$(PROGRAM):$(OBJS) $(HEADERS)
	$(CC) -o $@ $^ $(LIBDIR) $(LIBS)

.cpp.o:
	$(CC) $(INCDIR) -c $< -o $@

clean:
	rm -fr $(PROGRAM) $(OBJS)
