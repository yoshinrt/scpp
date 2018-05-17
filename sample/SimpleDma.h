#include "common.h"

#include "SimpleDmaReg.h"
#include "SimpleDmaCore.h"

template<int CH_NUM = 1>
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
	
	//*** ScppAutoMember outputputs the signals 
	//*** that generated automatically by ScppInstance.
	
	// $ScppAutoMember
	
	SimpleDmaReg *u_SimpleDmaReg;
	SimpleDmaCore *u_SimpleDmaCore;
	
	SC_CTOR( SimpleDma ) :
		//*** ScppIntializer generates member initializers
		//*** for setting name of sc_signal etc.
		
		// $ScppInitializer
	{
		//*** ScppSensitive outputs sensitivity lists
		//*** written near the function body.
		
		// $ScppSensitive( "." )
		
		/*** ScppInstance automatically connects signals with submodule
		/*** ports and automatically generates missing signals.
		
		/* $ScppInstance(
			SimpleDmaReg, u_SimpleDmaReg, "SimpleDmaReg.h",
			"/(Addr|.Data|Write|NCE)/Reg$1/",
		) */
		
		/* $ScppInstance(
			SimpleDmaCore, u_SimpleDmaCore, "SimpleDmaCore.h"
		) */
		
		//*** ScppSigTrace generates code for signal dump.
		
		// $ScppSigTrace
	}
};
