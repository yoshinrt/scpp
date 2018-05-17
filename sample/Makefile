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

run: $(PROGRAM)
	SYSTEMC_DISABLE_COPYRIGHT_MESSAGE=1 ./$(PROGRAM)

test.cpp: SimpleDma.h SimpleDmaReg.h SimpleDmaCore.h
SimpleDma.h: SimpleDmaReg.h SimpleDmaCore.h

$(PROGRAM): $(OBJS)
	$(CXX) -o $@ $^ $(LIBDIR) $(LIBS)

test.o: test.cpp $(HEADERS)

#-----
%.cpp: %.scpp.cpp
	$(SCPP) -o $@ $<

%.h: %.scpp.h
	$(SCPP) -o $@ $<

%.gch: %
	$(CXX) $(CXXFLAGS) $<

clean:
	rm -fr $(PROGRAM) *.o *.tmp *.gch *.list *.bak *.vcd `ls *.scpp.* | sed 's/\.scpp\././'`
