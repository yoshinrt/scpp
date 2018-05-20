#include "SimpleDma.h"

sc_trace_file *ScppTraceFile;

#define repeat( n )	for( int i = 0; i < ( n ); ++i )
#define Wait( n )	repeat( n ) wait()

SC_MODULE( sim_top ){
	
	sc_in_clk clk;
	// $ScppAutoMemberSim
	
	unsigned int *Sram;
	
	SC_CTOR( sim_top ) :
		// $ScppInitializer
	{
		// $ScppInstance( SimpleDma<8>, SimpleDma0, "SimpleDma.h" )
		
		// $ScppSensitive( "." )
		
		#define SRAM_SIZE 0x10000
		Sram = new unsigned int[ SRAM_SIZE ];
		for( int i = 0; i < SRAM_SIZE; ++i ){
			Sram[ i ] = i;
		}
	}
	
	void WriteReg( int ch, sc_uint<32> Addr, sc_uint<32> Data ){
		RegAddr.write( ch * 16 + Addr );
		RegWrite.write( true );
		RegWData.write( Data );
		RegNce.write( false );
		wait();
		
		RegNce.write( true );
	}
	
	sc_uint<32> ReadReg( int ch, sc_uint<32> Addr ){
		RegAddr.write( ch * 16 + Addr );
		RegWrite.write( false );
		RegNce.write( false );
		wait();
		
		RegNce.write( true );
		wait();
		
		return RegRData.read();
	}
	
	// $ScppCthread( clk.pos())
	void sim_main( void ){
		nrst.write( false );
		RegNce.write( true );
		
		Wait( 5 );
		nrst.write( true );
		
		// start DMA ch0
		WriteReg( 0, REG_SRCADDR,	0x1000 );
		WriteReg( 0, REG_DSTADDR,	0x2000 );
		WriteReg( 0, REG_CNT,		0x10 );
		WriteReg( 0, REG_CTRL,		1 );
		
		// start DMA ch2
		WriteReg( 2, REG_SRCADDR,	0x3000 );
		WriteReg( 2, REG_DSTADDR,	0x4000 );
		WriteReg( 2, REG_CNT,		0x8 );
		WriteReg( 2, REG_CTRL,		1 );
		
		Wait( 1 );
		// wait for DMA ch2 completion
		while( ReadReg( 2, REG_CTRL )) wait();
		Wait( 5 );
		
		sc_stop();
	}
	
	// SRAM model
	// $ScppCthread( clk.pos())
	void SramModel( void ){
		while( 1 ){
			if( !SramNce.read()){
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
	ScppTraceFile = sc_create_vcd_trace_file( "simple_dma" );
	ScppTraceFile->set_time_unit( 1.0, SC_NS );
	
	sc_clock clk( "clk", 10, SC_NS );	///<クロック信号生成
	
	sim_top sim_top0( "sim_top0" );
	sim_top0.clk( clk );
	
	sc_start( SC_ZERO_TIME );
	sc_start();
	
	sc_close_vcd_trace_file(ScppTraceFile);
	return 0;
}
