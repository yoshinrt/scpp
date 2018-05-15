#include "SimpleDmaReg.h"

// $ScppCthread( clk.pos(), nrst, false )
void SimpleDmaCore:Main( void ){
	
	sc_uint<32>	src_addr;
	sc_uint<32>	dst_addr;
	sc_uint<32> cnt;
	
	Busy.write( 0 );
	SramAddr.write( 0 );
	SramWData.write( 0 );
	SramNCE.write( 0 );
	SramWrite.write( 0 );
	
	wait();
	
	while( 1 ){
		
		bool busy = Busy.read();
		bool run  = Run.read();
		
		// start DMA
		if( !busy && run ){
			src_addr = SrcAddr.read();
			dst_addr = DstAddr.read();
			cnt  = XferCnt.read();
			Busy.write( true );
		}
		
		else if( busy ){
			// read SRAM
			SramNCE.write( false );
			SramWrite.write( false );
			SramAddr.write( src_addr );
			++src_addr;
			wait();
			
			// write SRAM
			SramWrite.write( true );
			SramAddr.write( dst_addr );
			++dst_addr
			--cnt;
			wait();
			
			if( cnt == 0 ){
				SramNCE.write( true );
				Busy.write( false );
			}
		}
		
		wait();
	}
}
