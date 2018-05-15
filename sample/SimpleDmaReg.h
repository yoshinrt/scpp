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
	
	// $ScppAutoSignal Begin
	// $ScppEnd
	
	SC_CTOR( SimpleDmaReg ) :
		// $ScppInitializer Begin
		clk( "clk" ),
		nrst( "nrst" ),
		RegAddr( "RegAddr" ),
		RegWData( "RegWData" ),
		RegNCE( "RegNCE" ),
		RegWrite( "RegWrite" ),
		RegRData( "RegRData" ),
		SrcAddr( "SrcAddr" ),
		DstAddr( "DstAddr" ),
		XferCnt( "XferCnt" ),
		Run( "Run" ),
		Busy( "Busy" )
		// $ScppEnd
	{
		// $ScppSensitive( "SimpleDmaReg.cpp" ) Begin
		SC_CTHREAD( RegReadThread, clk.pos() );
		reset_signal_is( nrst, true );
		
		SC_CTHREAD( RegWriteThread, clk.pos() );
		reset_signal_is( nrst, true );
		
		// $ScppEnd
		
		// $ScppSigTrace Begin
		#ifdef VCD_WAVE
		sc_trace( trace_f, clk, std::string( this->name()) + ".clk" );
		sc_trace( trace_f, nrst, std::string( this->name()) + ".nrst" );
		sc_trace( trace_f, RegAddr, std::string( this->name()) + ".RegAddr" );
		sc_trace( trace_f, RegWData, std::string( this->name()) + ".RegWData" );
		sc_trace( trace_f, RegNCE, std::string( this->name()) + ".RegNCE" );
		sc_trace( trace_f, RegWrite, std::string( this->name()) + ".RegWrite" );
		sc_trace( trace_f, RegRData, std::string( this->name()) + ".RegRData" );
		sc_trace( trace_f, SrcAddr, std::string( this->name()) + ".SrcAddr" );
		sc_trace( trace_f, DstAddr, std::string( this->name()) + ".DstAddr" );
		sc_trace( trace_f, XferCnt, std::string( this->name()) + ".XferCnt" );
		sc_trace( trace_f, Run, std::string( this->name()) + ".Run" );
		sc_trace( trace_f, Busy, std::string( this->name()) + ".Busy" );
		#endif // VCD_WAVE
		// $ScppEnd
	}
	
	void RegReadThread( void );
	void RegWriteThread( void );
};
