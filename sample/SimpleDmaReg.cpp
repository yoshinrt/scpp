#include "SimpleDmaReg.h"

// $ScppCthread( clk.pos(), nrst, "an" )
void SimpleDmaReg::RegWriteThread( void ){
	SrcAddr.write( 0 );
	DstAddr.write( 0 );
	XferCnt.write( 0 );
	
	wait();
	
	while( 1 ){
		
		sc_uint<32>	WriteData = WData.read();
		
		if( !Nce.read() && Write.read()){
			switch( Addr.read().range( 3, 0 )){
				case REG_SRCADDR:	SrcAddr.write( WriteData );	break;
				case REG_DSTADDR:	DstAddr.write( WriteData );	break;
				case REG_CNT:		XferCnt.write( WriteData );	break;
			}
		}
		wait();
	}
}

// $ScppCthread( clk.pos(), nrst, "an" )
void SimpleDmaReg::CtrlReg( void ){
	Run.write( false );
	
	wait();
	
	while( 1 ){
		if( !Nce.read() && Write.read() && Addr.read().range( 3, 0 ) == REG_CTRL ){
			Run.write( WData.read());
		}else if( Done.read()){
			Run.write( false );
		}
		wait();
	}
}

// $ScppCthread( clk.pos(), nrst, "an" )
void SimpleDmaReg::RegReadThread( void ){
	RData.write( 0 );
	
	wait();
	
	while( 1 ){
		
		sc_uint<32>	ReadData = 0;
		
		if( !Nce.read()){
			switch( Addr.read().range( 3, 0 )){
				case REG_SRCADDR:	ReadData = SrcAddr.read();	break;
				case REG_DSTADDR:	ReadData = DstAddr.read();	break;
				case REG_CNT:		ReadData = XferCnt.read();	break;
				case REG_CTRL:		ReadData = Run.read();		break;
			}
		}
		
		RData.write( ReadData );
		
		wait();
	}
}
