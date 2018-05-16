#include "SimpleDmaReg.h"

// $ScppCthread( clk.pos(), nrst, true )
void SimpleDmaReg::RegWriteThread( void ){
	SrcAddr.write( 0 );
	DstAddr.write( 0 );
	XferCnt.write( 0 );
	Run.write( false );
	
	wait();
	
	while( 1 ){
		
		sc_uint<32>	WriteData = WData.read();
		
		if( !NCE.read() & Write.read()){
			switch( Addr.read()){
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
	RData.write( 0 );
	
	wait();
	
	while( 1 ){
		
		sc_uint<32>	ReadData;
		
		if( !NCE.read()){
			switch( Addr.read()){
				case REG_SRCADDR:	ReadData = SrcAddr.read();	break;
				case REG_DSTADDR:	ReadData = DstAddr.read();	break;
				case REG_CNT:		ReadData = XferCnt.read();	break;
				case REG_CTRL:		ReadData = Busy.read();		break;
			}
			RData.write( ReadData );
		}
		
		wait();
	}
}
