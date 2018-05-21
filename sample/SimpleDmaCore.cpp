#include "SimpleDmaCore.h"

// $ScppCthread( clk.pos(), nrst, "an" )
void SimpleDmaCore::Main( void ){
	
	sc_uint<32>	src_addr;
	sc_uint<32>	dst_addr;
	sc_uint<32> cnt;
	
	Done.write( 0 );
	SramAddr.write( 0 );
	SramNce.write( 1 );
	SramWrite.write( 0 );
	RunningCh.write( 0 );
	
	wait();
	
	while( 1 ){
		
		// start DMA
		SramNce.write( true );
		Done.write( false );
		while( !Run.read()) wait();
		
		src_addr = SrcAddr.read();
		dst_addr = DstAddr.read();
		cnt  = XferCnt.read();
		RunningCh.write( SelectedCh.read());
		wait();
		
		while( cnt ){
			// read SRAM
			SramNce.write( false );
			SramWrite.write( false );
			SramAddr.write( src_addr );
			if( cnt == 1 ) Done.write( true );
			++src_addr;
			wait();
			
			// write SRAM
			SramWrite.write( true );
			SramAddr.write( dst_addr );
			Done.write( false );
			--cnt;
			++dst_addr;
			wait();
		}
	}
}
