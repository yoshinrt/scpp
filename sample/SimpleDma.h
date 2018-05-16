#include "common.h"

#include "SimpleDmaReg.h"
#include "SimpleDmaCore.h"

SC_MODULE( SimpleDma ){
	
	sc_in_clk			clk;
	sc_in<bool>			nrst;
	
	// register bus
	sc_in<sc_uint<32>>	RegAddr;
	sc_in<sc_uint<32>>	RegWData;
	sc_in<bool>			RegNCE;
	sc_in<bool>			RegWrite;
	sc_out<sc_uint<32>>	RegRData;
	
	// SRAM bus
	sc_out<sc_uint<32>>	SramAddr;
	sc_out<sc_uint<32>>	SramWData;
	sc_out<bool>		SramNCE;
	sc_out<bool>		SramWrite;
	sc_in<sc_uint<32>>	SramRData;
	
	// $ScppAutoSignal
	
	SimpleDmaReg *SimpleDmaReg0;
	SimpleDmaCore *SimpleDmaCore0;
	
	SC_CTOR( SimpleDma ) :
		// $ScppInitializer
	{
		// $ScppSensitive( "." )
		
		/* $ScppInstance(
			SimpleDmaReg, SimpleDmaReg0, "SimpleDmaReg.h"
		) */
		
		/* $ScppInstance(
			SimpleDmaCore, SimpleDmaCore0, "SimpleDmaCore.h"
		) */
		
		// $ScppSigTrace
	}
};
