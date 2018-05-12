PROGRAM = sc
ARCH    = cygwin
SYSTEMC = $(HOME)/systemc-2.3.2

INCDIR = -I. \
         -I$(SYSTEMC)/include/
LIBDIR = -L$(SYSTEMC)/lib-$(ARCH)/
LIBS   = -lsystemc -lm 

CXXFLAGS = $(INCDIR) -O2 -DVCD_WAVE

SRCS = test.cpp sc.cpp
OBJS = $(SRCS:.cpp=.o)
HEADERS = sig_trace.h common.h

go:
	\rm -f *.tmp
	./scpp.pl -v sc.h
	./scpp.pl -v test.cpp
	make -j 4 all

all: $(PROGRAM)
	SYSTEMC_DISABLE_COPYRIGHT_MESSAGE=1 ./$(PROGRAM)

$(PROGRAM): $(OBJS)
	$(CXX) -o $@ $^ $(LIBDIR) $(LIBS)

test.o: test.cpp $(HEADERS)
sc.o: sc.cpp $(HEADERS)

%.gch: %
	$(CXX) $(CXXFLAGS) $<

clean:
	rm -fr $(PROGRAM) *.o *.tmp *.gch *.list
