#include "SimpleDmaCore.h"

// $ScppCthread( clk.pos(), nrst, true )
void SimpleDmaCore::Main( void ){
	
	sc_uint<32>	src_addr;
	sc_uint<32>	dst_addr;
	sc_uint<32> cnt;
	
	Done.write( 0 );
	SramAddr.write( 0 );
	SramNCE.write( 0 );
	SramWrite.write( 0 );
	
	wait();
	
	while( 1 ){
		
		// start DMA
		while( !Run.read()) wait();
		
		src_addr = SrcAddr.read();
		dst_addr = DstAddr.read();
		cnt  = XferCnt.read();
		wait();
		
		while( cnt ){
			// read SRAM
			SramNCE.write( false );
			SramWrite.write( false );
			SramAddr.write( src_addr );
			++src_addr;
			wait();
			
			// write SRAM
			SramWrite.write( true );
			SramAddr.write( dst_addr );
			if( cnt == 1 ) Done.write( true );
			--cnt;
			++dst_addr;
			wait();
		}
		SramNCE.write( true );
		Done.write( false );
		wait();
	}
}
