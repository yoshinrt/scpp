#include "common.h"
#include "sig_trace.h"

#ifdef VCD_WAVE
extern sc_trace_file *trace_f;
#endif

SC_MODULE( mul ){
	
	sc_in_clk	zclk;
	sc_in<bool>	nrst;
	
	sc_in<sc_uint<32>>	mul_a;
	sc_in<sc_uint<32>>	mul_b;
	sc_out<sc_uint<32>>	mul_c;
	
	// $ScppAutoSignal Begin
	// $ScppEnd
	
	SC_CTOR( mul ) :
		// $ScppInitializer Begin
		zclk( "zclk" ),
		nrst( "nrst" ),
		mul_a( "mul_a" ),
		mul_b( "mul_b" ),
		mul_c( "mul_c" )
		// $ScppEnd
	{
		// $ScppSensitive( "sc.cpp" ) Begin
		SC_CTHREAD( MulCThread, zclk.pos() );
		reset_signal_is( nrst, false );
		
		// $ScppEnd
		// $ScppSigTrace Begin
		#ifdef VCD_WAVE
		sc_trace( trace_f, zclk, zclk.name());
		sc_trace( trace_f, nrst, nrst.name());
		sc_trace( trace_f, mul_a, mul_a.name());
		sc_trace( trace_f, mul_b, mul_b.name());
		sc_trace( trace_f, mul_c, mul_c.name());
		#endif // VCD_WAVE
		// $ScppEnd
	}
	
	// $ScppCthread( zclk.pos(), nrst, false )
	void MulCThread( void ){
		mul_c.write( 0 );
		wait();
		
		while( 1 ){
			mul_c.write( mul_a.read() * mul_b.read());
			wait();
		}
	}
};

SC_MODULE( adder ){
	
	sc_in_clk	clk;
	sc_in<bool>	nrst;
	
	sc_in<sc_uint<32>>	a;
	sc_in<sc_uint<32>>	b;
	
	sc_out<sc_uint<32>>	c;
	sc_out<sc_uint<32>>	cthread_cc;
	sc_out<sc_uint<32>> mul_c;
	
	// $ScppAutoSignal Begin
	// $ScppEnd
	
	
	mul	*mul1;
	
	SC_CTOR( adder ) :
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
		// $ScppSensitive( "sc.cpp" ) Begin
		SC_METHOD( AdderMethod );
		sensitive << a << b;
		
		SC_CTHREAD( AdderCThread, clk.pos() );
		reset_signal_is( nrst, false );
		
		// $ScppEnd
		
		/* $ScppInstance(
			mul, mul1, ".",
			/mul_([ab])/$1/,
			/zclk/clk/
		) Begin */
		mul1 = new mul( "mul" );
		mul1->zclk( clk );
		mul1->nrst( nrst );
		mul1->mul_a( a );
		mul1->mul_b( b );
		mul1->mul_c( mul_c );
		// $ScppEnd
		
		// $ScppSigTrace Begin
		#ifdef VCD_WAVE
		sc_trace( trace_f, clk, clk.name());
		sc_trace( trace_f, nrst, nrst.name());
		sc_trace( trace_f, a, a.name());
		sc_trace( trace_f, b, b.name());
		sc_trace( trace_f, c, c.name());
		sc_trace( trace_f, cthread_cc, cthread_cc.name());
		sc_trace( trace_f, mul_c, mul_c.name());
		#endif // VCD_WAVE
		// $ScppEnd
	}
	
	void AdderCThread( void );
	
	// $ScppMethod( a, b )
	void AdderMethod( void ){
		cthread_cc.write( a.read() + b.read());
	}
};
