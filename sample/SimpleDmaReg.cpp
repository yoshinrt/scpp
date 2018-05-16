#include "SimpleDmaReg.h"

// $ScppCthread( clk.pos(), nrst, true )
void SimpleDmaReg::RegWriteThread( void ){
	SrcAddr.write( 0 );
	DstAddr.write( 0 );
	XferCnt.write( 0 );
	Run.write( false );
	
	wait();
	
	while( 1 ){
		
		sc_uint<32>	WriteData = RegWData.read();
		
		if( !RegNCE.read() & RegWrite.read()){
			switch( RegAddr.read()){
				case REG_SRCADDR:	SrcAddr.write( WriteData );	break;
				case REG_DSTADDR:	DstAddr.write( WriteData );	break;
				case REG_CNT:		XferCnt.write( WriteData );	break;
				case REG_CTRL:		Run.write( WriteData );		break;
			}
		}
		wait();
	}
}

// $ScppCthread( clk.pos(), nrst, true )
void SimpleDmaReg::RegReadThread( void ){
	RegRData.write( 0 );
	
	wait();
	
	while( 1 ){
		
		sc_uint<32>	ReadData;
		
		if( !RegNCE.read()){
			switch( RegAddr.read()){
				case REG_SRCADDR:	ReadData = SrcAddr.read();	break;
				case REG_DSTADDR:	ReadData = DstAddr.read();	break;
				case REG_CNT:		ReadData = XferCnt.read();	break;
				case REG_CTRL:		ReadData = Busy.read();		break;
			}
			RegRData.write( ReadData );
		}
		
		wait();
	}
}
