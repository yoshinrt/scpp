#include "common.h"

SC_MODULE( SimpleDmaCore ){
	
	sc_in_clk			clk;
	sc_in<bool>			nrst;
	
	// internal ctrl signal
	sc_in<sc_uint<32>>	SrcAddr;
	sc_in<sc_uint<32>>	DstAddr;
	sc_in<sc_uint<32>>	XferCnt;
	sc_in<bool>			Run;
	sc_out<bool>		Busy;
	
	// SRAM bus
	sc_out<sc_uint<32>>	SramAddr;
	sc_out<sc_uint<32>>	SramWData;
	sc_out<bool>		SramNCE;
	sc_out<bool>		SramWrite;
	sc_in<sc_uint<32>>	SramRData;
	
	// $ScppAutoSignal Begin
	// $ScppEnd
	
	SC_CTOR( SimpleDmaCore ) :
		// $ScppInitializer Begin
		clk( "clk" ),
		nrst( "nrst" ),
		SrcAddr( "SrcAddr" ),
		DstAddr( "DstAddr" ),
		XferCnt( "XferCnt" ),
		Run( "Run" ),
		Busy( "Busy" ),
		SramAddr( "SramAddr" ),
		SramWData( "SramWData" ),
		SramNCE( "SramNCE" ),
		SramWrite( "SramWrite" ),
		SramRData( "SramRData" )
		// $ScppEnd
	{
		// $ScppSensitive( "SimpleDmaCore.cpp" ) Begin
		// $ScppEnd
		
		// $ScppSigTrace Begin
		#ifdef VCD_WAVE
		sc_trace( trace_f, clk, std::string( this->name()) + ".clk" );
		sc_trace( trace_f, nrst, std::string( this->name()) + ".nrst" );
		sc_trace( trace_f, SrcAddr, std::string( this->name()) + ".SrcAddr" );
		sc_trace( trace_f, DstAddr, std::string( this->name()) + ".DstAddr" );
		sc_trace( trace_f, XferCnt, std::string( this->name()) + ".XferCnt" );
		sc_trace( trace_f, Run, std::string( this->name()) + ".Run" );
		sc_trace( trace_f, Busy, std::string( this->name()) + ".Busy" );
		sc_trace( trace_f, SramAddr, std::string( this->name()) + ".SramAddr" );
		sc_trace( trace_f, SramWData, std::string( this->name()) + ".SramWData" );
		sc_trace( trace_f, SramNCE, std::string( this->name()) + ".SramNCE" );
		sc_trace( trace_f, SramWrite, std::string( this->name()) + ".SramWrite" );
		sc_trace( trace_f, SramRData, std::string( this->name()) + ".SramRData" );
		#endif // VCD_WAVE
		// $ScppEnd
	}
};
