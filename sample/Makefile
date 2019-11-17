PROGRAM	= simple_dma
SYSTEMC	= $(HOME)/systemc-2.3.3

INCDIR	= -I. -I$(SYSTEMC)/include/
LIBDIR	= `echo $(SYSTEMC)/lib-*/`
LIBS	= -lsystemc -lm 

CXXFLAGS	= $(INCDIR) -O2 -DVCD_WAVE

SRCS	= test.cpp SimpleDmaReg.cpp SimpleDmaCore.cpp
OBJS	= $(SRCS:.cpp=.o)
HEADERS	= SimpleDmaReg.h SimpleDmaCore.h SimpleDma.h common.h

SCPP	= ../scpp.pl $(INCDIR) -v

run: $(PROGRAM)
	LD_LIBRARY_PATH=$(LIBDIR):$(LD_LIBRARY_PATH) SYSTEMC_DISABLE_COPYRIGHT_MESSAGE=1 ./$(PROGRAM)

$(PROGRAM): $(OBJS)
	$(CXX) -o $@ $^ -L$(LIBDIR) $(LIBS)

test.cpp: $(HEADERS)
SimpleDma.h: SimpleDmaReg.h SimpleDmaCore.h
SimpleDmaReg.h: SimpleDmaReg.cpp
SimpleDmaCore.h: SimpleDmaCore.cpp

SimpleDma.o: SimpleDma.h
SimpleDmaReg.o: SimpleDmaReg.h
SimpleDmaCore.o: SimpleDmaCore.h

#-----
%.cpp: %.scpp.cpp
	$(SCPP) -o $@ $<

%.h: %.scpp.h
	$(SCPP) -o $@ $<

%.gch: %
	$(CXX) $(CXXFLAGS) $<

clean:
	rm -fr $(PROGRAM) *.o *.tmp *.gch *.list *.bak *.vcd `ls *.scpp.* | sed 's/\.scpp\././'`
