#include "common.h"

SC_MODULE( SimpleDmaReg ){
	
	sc_in_clk			clk;
	sc_in<bool>			nrst;
	
	// regsister bus
	sc_in<sc_uint<32>>	RegAddr;
	sc_in<sc_uint<32>>	RegWData;
	sc_in<bool>			RegNCE;
	sc_in<bool>			RegWrite;
	sc_out<sc_uint<32>>	RegRData;
	
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
