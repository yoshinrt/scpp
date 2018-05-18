#ifndef _SimpleDmaCore_h
#define _SimpleDmaCore_h

#include "common.h"

SC_MODULE( SimpleDmaCore ){
	
	sc_in_clk			clk;
	sc_in<bool>			nrst;
	
	// internal ctrl signal
	sc_in<sc_uint<32>>	SrcAddr;
	sc_in<sc_uint<32>>	DstAddr;
	sc_in<sc_uint<32>>	XferCnt;
	sc_in<bool>			Run;
	sc_out<bool>		Done;
	
	// SRAM bus
	sc_out<sc_uint<32>>	SramAddr;
	sc_out<sc_uint<32>>	SramWData;
	sc_out<bool>		SramNce;
	sc_out<bool>		SramWrite;
	sc_in<sc_uint<32>>	SramRData;
	
	// $ScppAutoMember
	
	SC_CTOR( SimpleDmaCore ) :
		// $ScppInitializer
	{
		// $ScppSensitive( "SimpleDmaCore.cpp" )
		
		// $ScppSigTrace
	}
	
	// $ScppMethod
	void WDataAssign( void ){
		SramWData.write( SramRData.read());
	}
};
#endif
