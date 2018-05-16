#include "common.h"

SC_MODULE( SimpleDmaReg ){
	
	sc_in_clk			clk;
	sc_in<bool>			nrst;
	
	// regsister bus
	sc_in<sc_uint<32>>	Addr;
	sc_in<sc_uint<32>>	WData;
	sc_in<bool>			NCE;
	sc_in<bool>			Write;
	sc_out<sc_uint<32>>	RData;
	
	// internal ctrl signal
	sc_out<sc_uint<32>>	SrcAddr;
	sc_out<sc_uint<32>>	DstAddr;
	sc_out<sc_uint<32>>	XferCnt;
	sc_out<bool>		Run;
	sc_in<bool>			Busy;
	
	// $ScppAutoSignal
	
	SC_CTOR( SimpleDmaReg ) :
		// $ScppInitializer
	{
		// $ScppSensitive( "SimpleDmaReg.cpp" )
		
		// $ScppSigTrace
	}
	
	void RegReadThread( void );
	void RegWriteThread( void );
};
