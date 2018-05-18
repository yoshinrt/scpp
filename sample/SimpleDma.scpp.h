#ifndef _SimpleDma_h
#define _SimpleDma_h

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
	sc_in<bool>			RegNce;
	sc_in<bool>			RegWrite;
	sc_out<sc_uint<32>>	RegRData;
	
	// SRAM bus
	sc_out<sc_uint<32>>	SramAddr;
	sc_out<sc_uint<32>>	SramWData;
	sc_out<bool>		SramNce;
	sc_out<bool>		SramWrite;
	sc_in<sc_uint<32>>	SramRData;
	
	//*** ScppAutoMember outputputs the signals 
	//*** that generated automatically by ScppInstance,
	//*** and outputs function prototype declarations
	//*** that generated automatically by ScppSensivive.
	
	// $ScppAutoMember
	
	SC_CTOR( SimpleDma ) :
		//*** ScppIntializer generates member initializers
		//*** for setting name of sc_signal etc.
		
		// $ScppInitializer
	{
		//*** ScppSensitive outputs sensitivity lists
		//*** written near the function body,
		//*** and generates function prototype declarations.
		
		// $ScppSensitive( "." )
		
		//*** ScppInstance automatically connects signals with submodule
		//*** ports and automatically generates missing signals.
		
		/* $ScppInstance(
			SimpleDmaCore, u_SimpleDmaCore, "SimpleDmaCore.h",
			"@clk|nrst|Sram.*@@",
			"///W",
		) */
		
		/* $ScppInstance(
			SimpleDmaReg, u_SimpleDmaReg[ CH_NUM ], "SimpleDmaReg.h",
			"/clk|nrst//",
			"/(Addr|WData|Write)/Reg$1/",
			"/(RData)/Reg$1Ch[]/W",
			"//$1Ch[]/W",
		) */
		
		//*** ScppSigTrace generates code for signal dump.
		
		// $ScppSigTrace
	}
};

// $ScppMethod
template<int CH_NUM>
void SimpleDma<CH_NUM>::AddrDecorder( void ){
	for( int i = 0; i < CH_NUM; ++i ){
		if( RegNce.read()){
			NceCh[ i ].write( true );
		}else{
			NceCh[ i ].write( RegAddr.read().range( 7, 4 ) != i );
		}
	}
}

/* $ScppMethod(
	DstAddrCh[0], RunCh[0], SrcAddrCh[0], XferCntCh[0],
	DstAddrCh[1], RunCh[1], SrcAddrCh[1], XferCntCh[1],
	DstAddrCh[2], RunCh[2], SrcAddrCh[2], XferCntCh[2],
	DstAddrCh[3], RunCh[3], SrcAddrCh[3], XferCntCh[3],
	DstAddrCh[4], RunCh[4], SrcAddrCh[4], XferCntCh[4],
	DstAddrCh[5], RunCh[5], SrcAddrCh[5], XferCntCh[5],
	DstAddrCh[6], RunCh[6], SrcAddrCh[6], XferCntCh[6],
	DstAddrCh[7], RunCh[7], SrcAddrCh[7], XferCntCh[7],
	Done
)*/
template<int CH_NUM>
void SimpleDma<CH_NUM>::ArbiterSelector( void ){
	int ch_sel = 0;
	
	// priority encorder
	for( ch_sel = 0; ch_sel < CH_NUM; ++ch_sel ){
		if( RunCh[ ch_sel ].read()) break;
	}
	
	// ch selector
	if( ch_sel < CH_NUM ){
		SrcAddr.write( SrcAddrCh[ ch_sel ].read());
		DstAddr.write( DstAddrCh[ ch_sel ].read());
		XferCnt.write( XferCntCh[ ch_sel ].read());
		Run.write( true );
	}else{
		SrcAddr.write( 0 );
		DstAddr.write( 0 );
		XferCnt.write( 0 );
		Run.write( false );
	}
	
	// done selector
	for( int i = 0; i < CH_NUM; ++i ){
		DoneCh[ i ].write( i == ch_sel && Done.read());
	}
}

/* $ScppMethod(
	RegRDataCh[0],
	RegRDataCh[1],
	RegRDataCh[2],
	RegRDataCh[3],
	RegRDataCh[4],
	RegRDataCh[5],
	RegRDataCh[6],
	RegRDataCh[7],
)*/
template<int CH_NUM>
void SimpleDma<CH_NUM>::RDataSelector( void ){
	
	sc_uint<32> data = 0;
	
	// priority encorder
	for( int i = 0; i < CH_NUM; ++i ){
		data |= RegRDataCh[ i ].read();
	}
	
	RegRData.write( data );
}
#endif
