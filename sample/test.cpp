#include "SimpleDma.h"

sc_trace_file *trace_f;

#define repeat( n )	for( int i = 0; i < ( n ); ++i )
#define Wait( n )	repeat( n ) wait()

SC_MODULE( sim_top ){
	
	sc_in_clk clk;
	// $ScppAutoSignalSim
	
	SimpleDma *SimpleDma0;
	unsigned int *Sram;
	
	SC_CTOR( sim_top ) :
		// $ScppInitializer
	{
		// $ScppInstance( SimpleDma, SimpleDma0, "SimpleDma.h" )
		
		// $ScppSensitive( "." )
		
		#define SRAM_SIZE 0x10000
		Sram = new unsigned int[ SRAM_SIZE ];
		for( int i = 0; i < SRAM_SIZE; ++i ){
			Sram[ i ] = i;
		}
	}
	
	void WriteReg( sc_uint<32> Addr, sc_uint<32> Data ){
		RegAddr.write( Addr );
		RegWrite.write( true );
		RegWData.write( Data );
		RegNCE.write( false );
		wait();
		
		RegNCE.write( true );
	}
	
	sc_uint<32> ReadReg( sc_uint<32> Addr ){
		RegAddr.write( Addr );
		RegWrite.write( false );
		RegNCE.write( false );
		wait();
		
		RegNCE.write( true );
		wait();
		
		return RegRData.read();
	}
	
	// $ScppCthread( clk.pos())
	void sim_main( void ){
		nrst.write( true );
		RegNCE.write( true );
		
		Wait( 5 );
		nrst.write( false );
		
		WriteReg( REG_SRCADDR,	0x1000 );
		WriteReg( REG_DSTADDR,	0x2000 );
		WriteReg( REG_CNT,		0x10 );
		WriteReg( REG_CTRL,		1 );
		WriteReg( REG_CTRL,		0 );
		
		Wait( 1 );
		while( ReadReg( REG_CTRL )) wait();
		Wait( 5 );
		
		sc_stop();
	}
	
	// SRAM model
	// $ScppCthread( clk.pos())
	void SramModel( void ){
		while( 1 ){
			if( !SramNCE.read()){
				if( SramWrite.read()){
					// write SRAM
					Sram[ SramAddr.read() ] = SramWData.read();
				}else{
					// read SRAM
					SramRData.write( Sram[ SramAddr.read() ]);
				}
			}
			wait();
		}
	}
};

int sc_main( int argc, char **argv ){
	//トレースファイル関連
	trace_f = sc_create_vcd_trace_file( "simple_dma" );
	trace_f->set_time_unit( 1.0, SC_NS );
	
	sc_clock clk( "clk", 10, SC_NS, 0.5, 0, SC_NS, 0 );	///<クロック信号生成
	
	sim_top sim_top0( "sim_top0" );
	sim_top0.clk( clk );
	
	sc_start( SC_ZERO_TIME );
	sc_start();
	
	sc_close_vcd_trace_file(trace_f);
	return 0;
}
