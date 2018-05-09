CC = g++ -O2

PROGRAM = sc
ARCH    = cygwin
SYSTEMC = $(HOME)/systemc-2.3.1a

INCDIR = -I. \
         -I$(SYSTEMC)/include/
LIBDIR = -L$(SYSTEMC)/lib-$(ARCH)/
LIBS   = -lsystemc -lm 

SRCS = test.cpp sc.cpp
OBJS = $(SRCS:.cpp=.o)
HEADERS = sig_trace.h

go:
	\rm -f *.tmp
	./scpp.pl -v sc.h
	make all
	
all: $(PROGRAM)
	SYSTEMC_DISABLE_COPYRIGHT_MESSAGE=1 ./$(PROGRAM)

$(PROGRAM):$(OBJS) $(HEADERS)
	$(CC) -o $@ $^ $(LIBDIR) $(LIBS)

.cpp.o:
	$(CC) -DVCD_WAVE $(INCDIR) -c $< -o $@

clean:
	rm -fr $(PROGRAM) $(OBJS)
