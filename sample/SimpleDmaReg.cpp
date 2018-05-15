#include "SimpleDmaReg.h"

// $ScppCthread( clk.pos(), nrst, false )
void SimpleDmaReg:RegWriteThread( void ){
	SrcAddr.write( 0 );
	DstAddr.write( 0 );
	XferCnt.write( 0 );
	Run.write( false );
	
	wait();
	
	while( 1 ){
		
		sc_uint<32>	WriteData = RegWData.read();
		
		if( !RegNCE.read() && RegWrite.read()){
			switch( RegAddr.read()){
				REG_SRCADDR:	SrcAddr.write( WriteData );
				REG_DSTADDR:	DstAddr.write( WriteData );
				REG_CNT:		XferCnt.write( WriteData );
				REG_CTRL:		Run.write( WriteData );
			}
		}
		wait();
	}
}

// $ScppCthread( clk.pos, nrst, false )
void SimpleDmaReg:RegReadThread( void ){
	RegRData.write( 0 );
	
	wait();
	
	while( 1 ){
		
		sc_uint<32>	ReadData;
		
		if( !RegNCE.read()){
			switch( RegAddr.read()){
				REG_SRCADDR:	ReadData = SrcAddr.read();
				REG_DSTADDR:	ReadData = DstAddr.read();
				REG_CNT:		ReadData = XferCnt.read();
				REG_CTRL:		ReadData = Busy.read();
			}
		}
		wait();
	}
}
