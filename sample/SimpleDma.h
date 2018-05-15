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
	
	// $ScppAutoSignal Begin
	sc_signal<sc_uint<32>> SrcAddr;
	sc_signal<sc_uint<32>> DstAddr;
	sc_signal<sc_uint<32>> XferCnt;
	sc_signal<bool> Run;
	sc_signal<bool> Busy;
	// $ScppEnd
	
	SimpleDmaReg *SimpleDmaReg0;
	SimpleDmaCore *SimpleDmaCore0;
	
	SC_CTOR( SimpleDma ) :
		// $ScppInitializer Begin
		clk( "clk" ),
		nrst( "nrst" ),
		RegAddr( "RegAddr" ),
		RegWData( "RegWData" ),
		RegNCE( "RegNCE" ),
		RegWrite( "RegWrite" ),
		RegRData( "RegRData" ),
		SramAddr( "SramAddr" ),
		SramWData( "SramWData" ),
		SramNCE( "SramNCE" ),
		SramWrite( "SramWrite" ),
		SramRData( "SramRData" ),
		SrcAddr( "SrcAddr" ),
		DstAddr( "DstAddr" ),
		XferCnt( "XferCnt" ),
		Run( "Run" ),
		Busy( "Busy" )
		// $ScppEnd
	{
		// $ScppSensitive( "." ) Begin
		// $ScppEnd
		
		/* $ScppInstance(
			SimpleDmaReg, SimpleDmaReg0, "SimpleDmaReg.h"
		) Begin */
		SimpleDmaReg0 = new SimpleDmaReg( "SimpleDmaReg0" );
		SimpleDmaReg0->clk( clk );
		SimpleDmaReg0->nrst( nrst );
		SimpleDmaReg0->RegAddr( RegAddr );
		SimpleDmaReg0->RegWData( RegWData );
		SimpleDmaReg0->RegNCE( RegNCE );
		SimpleDmaReg0->RegWrite( RegWrite );
		SimpleDmaReg0->RegRData( RegRData );
		SimpleDmaReg0->SrcAddr( SrcAddr );
		SimpleDmaReg0->DstAddr( DstAddr );
		SimpleDmaReg0->XferCnt( XferCnt );
		SimpleDmaReg0->Run( Run );
		SimpleDmaReg0->Busy( Busy );
		// $ScppEnd
		
		/* $ScppInstance(
			SimpleDmaCore, SimpleDmaCore0, "SimpleDmaCore.h"
		) Begin */
		SimpleDmaCore0 = new SimpleDmaCore( "SimpleDmaCore0" );
		SimpleDmaCore0->clk( clk );
		SimpleDmaCore0->nrst( nrst );
		SimpleDmaCore0->SrcAddr( SrcAddr );
		SimpleDmaCore0->DstAddr( DstAddr );
		SimpleDmaCore0->XferCnt( XferCnt );
		SimpleDmaCore0->Run( Run );
		SimpleDmaCore0->Busy( Busy );
		SimpleDmaCore0->SramAddr( SramAddr );
		SimpleDmaCore0->SramWData( SramWData );
		SimpleDmaCore0->SramNCE( SramNCE );
		SimpleDmaCore0->SramWrite( SramWrite );
		SimpleDmaCore0->SramRData( SramRData );
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
		sc_trace( trace_f, SramAddr, std::string( this->name()) + ".SramAddr" );
		sc_trace( trace_f, SramWData, std::string( this->name()) + ".SramWData" );
		sc_trace( trace_f, SramNCE, std::string( this->name()) + ".SramNCE" );
		sc_trace( trace_f, SramWrite, std::string( this->name()) + ".SramWrite" );
		sc_trace( trace_f, SramRData, std::string( this->name()) + ".SramRData" );
		sc_trace( trace_f, SrcAddr, std::string( this->name()) + ".SrcAddr" );
		sc_trace( trace_f, DstAddr, std::string( this->name()) + ".DstAddr" );
		sc_trace( trace_f, XferCnt, std::string( this->name()) + ".XferCnt" );
		sc_trace( trace_f, Run, std::string( this->name()) + ".Run" );
		sc_trace( trace_f, Busy, std::string( this->name()) + ".Busy" );
		#endif // VCD_WAVE
		// $ScppEnd
	}
};
