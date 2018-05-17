PROGRAM = sc
ARCH    = cygwin
SYSTEMC = $(HOME)/systemc-2.3.2

INCDIR = -I. -I$(SYSTEMC)/include/
LIBDIR = -L$(SYSTEMC)/lib-$(ARCH)/
LIBS   = -lsystemc -lm 

CXXFLAGS = $(INCDIR) -O2 -DVCD_WAVE

SRCS = test.cpp SimpleDmaReg.cpp SimpleDmaCore.cpp
OBJS = $(SRCS:.cpp=.o)
HEADERS = SimpleDmaReg.h SimpleDmaCore.h SimpleDma.h common.h

SCPP	= ../scpp.pl $(INCDIR) -v

all:
	$(SCPP) SimpleDmaReg.h
	$(SCPP) SimpleDmaCore.h
	$(SCPP) SimpleDma.h
	$(SCPP) test.cpp
	make -j 4 run

run: $(PROGRAM)
	SYSTEMC_DISABLE_COPYRIGHT_MESSAGE=1 ./$(PROGRAM)

$(PROGRAM): $(OBJS)
	$(CXX) -o $@ $^ $(LIBDIR) $(LIBS)

test.o: test.cpp $(HEADERS)

%.gch: %
	$(CXX) $(CXXFLAGS) $<

clean:
	rm -fr $(PROGRAM) *.o *.tmp *.gch *.list *.bak
