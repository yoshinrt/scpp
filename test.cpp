#include "sc.h"

sc_trace_file *trace_f;

#define repeat( n )	for( int i = 0; i < ( n ); ++i )
#define Wait( n )	repeat( n ) wait()

SC_MODULE( sim_top ){
	
	sc_in_clk clk;
	// $ScppAutoSignalSim Begin
	sc_signal<bool> nrst;
	sc_signal<sc_uint<32>> a;
	sc_signal<sc_uint<32>> b;
	sc_signal<sc_uint<32>> c;
	sc_signal<sc_uint<32>> cthread_cc;
	sc_signal<sc_uint<32>> mul_c;
	// $ScppEnd
	
	adder *adder1;
	
	SC_CTOR( sim_top ) :
		// $ScppInitializer Begin
		clk( "clk" ),
		nrst( "nrst" ),
		a( "a" ),
		b( "b" ),
		c( "c" ),
		cthread_cc( "cthread_cc" ),
		mul_c( "mul_c" )
		// $ScppEnd
	{
		// $ScppInstance( adder, adder1, "sc.cpp" ) Begin
		adder1 = new adder( "adder" );
		adder1->clk( clk );
		adder1->nrst( nrst );
		adder1->a( a );
		adder1->b( b );
		adder1->c( c );
		adder1->cthread_cc( cthread_cc );
		adder1->mul_c( mul_c );
		// $ScppEnd
		
		// $ScppSensitive( "." ) Begin
		SC_THREAD( sim_main );
		sensitive << clk.pos();
		
		// $ScppEnd
	}
	
	// $ScppThread( clk.pos())
	void sim_main( void ){
		nrst.write( false );
		Wait( 5 );
		nrst.write( true );
		
		for( int i = 0; i < 10; ++i ){
			a.write( i );
			b.write( i * 100 );
			wait();
		}
		
		sc_stop();
	}
};

int sc_main( int argc, char **argv ){
	//トレースファイル関連
	trace_f = sc_create_vcd_trace_file( "adder" );
	trace_f->set_time_unit( 1.0, SC_NS );
	
	sc_clock clk( "clk", 10, SC_NS, 0.5, 0, SC_NS, 0 );	///<クロック信号生成
	
	sim_top sim_top1( "sim_top1" );
	sim_top1.clk( clk );
	
	sc_start( SC_ZERO_TIME );
	sc_start();
	
	sc_close_vcd_trace_file(trace_f);
	return 0;
}
