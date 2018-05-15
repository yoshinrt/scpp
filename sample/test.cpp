#include "SimpleDma.h"

sc_trace_file *trace_f;

#define repeat( n )	for( int i = 0; i < ( n ); ++i )
#define Wait( n )	repeat( n ) wait()

SC_MODULE( sim_top ){
	
	sc_in_clk clk;
	// $ScppAutoSignalSim Begin
	sc_signal<bool> nrst;
	sc_signal<sc_uint<32>> RegAddr;
	sc_signal<sc_uint<32>> RegWData;
	sc_signal<bool> RegNCE;
	sc_signal<bool> RegWrite;
	sc_signal<sc_uint<32>> RegRData;
	sc_signal<sc_uint<32>> SramAddr;
	sc_signal<sc_uint<32>> SramWData;
	sc_signal<bool> SramNCE;
	sc_signal<bool> SramWrite;
	sc_signal<sc_uint<32>> SramRData;
	// $ScppEnd
	
	SimpleDma *SimpleDma0;
	
	SC_CTOR( sim_top ) :
		// $ScppInitializer Begin
		clk( "clk" ),
		nrst( "nrst" ),
		RegAddr( "RegAddr" ),
		RegWData( "RegWData" ),
		RegNCE( "RegNCE" ),
		RegWrite( "RegWrite" ),
		RegRData( "RegRData" ),
		SramAddr( "SramAddr" ),
		SramWData( "SramWData" ),
		SramNCE( "SramNCE" ),
		SramWrite( "SramWrite" ),
		SramRData( "SramRData" )
		// $ScppEnd
	{
		// $ScppInstance( SimpleDma, SimpleDma0, "SimpleDma.h" ) Begin
		SimpleDma0 = new SimpleDma( "SimpleDma0" );
		SimpleDma0->clk( clk );
		SimpleDma0->nrst( nrst );
		SimpleDma0->RegAddr( RegAddr );
		SimpleDma0->RegWData( RegWData );
		SimpleDma0->RegNCE( RegNCE );
		SimpleDma0->RegWrite( RegWrite );
		SimpleDma0->RegRData( RegRData );
		SimpleDma0->SramAddr( SramAddr );
		SimpleDma0->SramWData( SramWData );
		SimpleDma0->SramNCE( SramNCE );
		SimpleDma0->SramWrite( SramWrite );
		SimpleDma0->SramRData( SramRData );
		// $ScppEnd
		
		// $ScppSensitive( "." ) Begin
		SC_THREAD( sim_main );
		sensitive << clk.pos();
		
		// $ScppEnd
	}
	
	void RegWrite( sc_uint<32> Addr, sc_uint<32> Data ){
		RegAddr.write( Addr );
		RegWData.write( Data );
		RegNCE.write( false );
		wait();
		
		RegNCE.write( true );
	}
	
	// $ScppThread( clk.pos())
	void sim_main( void ){
		nrst.write( false );
		RegNCE.write( true );
		
		Wait( 5 );
		nrst.write( true );
		
		RegWrite( REG_SRCADDR,	0x1000 );
		RegWrite( REG_DSTADDR,	0x2000 );
		RegWrite( REG_CNT,		0x10 );
		RegWrite( REG_CTRL,		1 );
		
		Wait( 0x20 );
		
		sc_stop();
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
