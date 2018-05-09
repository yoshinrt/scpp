#include <systemc.h>
#include "sig_trace.h"

sc_trace_file *trace_f;

SC_MODULE( mul ){
	
	sc_in_clk	zclk;
	sc_in<bool>	nrst;
	
	sc_in<sc_uint<32>>	mul_a;
	sc_in<sc_uint<32>>	mul_b;
	sc_out<sc_uint<32>>	mul_c;
	
	// $ScppAutoSignal
	
	SC_CTOR( mul ) :
		// $ScppInitializer
	{
		// $ScppSensitive( "." )
		// $ScppSigTrace
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
	
	// $ScppAutoSignal
	
	
	mul	*mul1;
	
	SC_CTOR( adder ) :
		// $ScppInitializer
	{
		// $ScppSensitive( "." )
		
		/* $ScppInstance(
			mul, mul1, ".",
			/mul_([ab])/$1/,
			/zclk/clk/
		) */
		
		// $ScppSigTrace
	}
	
	void AdderCThread( void );
	
	// $ScppMethod( a, b )
	void AdderMethod( void ){
		cthread_cc.write( a.read() + b.read());
	}
};

// $ScppCthread( clk.pos(), nrst, false )
void adder::AdderCThread( void ){
	c.write( 0 );
	wait();
	
	while( 1 ){
		c.write( a.read() + b.read());
		wait();
	}
}

int sc_main(int argc, char* argv[])
{
	//トレースファイル関連
	trace_f = sc_create_vcd_trace_file( "adder" );
	trace_f->set_time_unit( 1.0, SC_NS );
	
	sc_clock clk( "clk", 10, SC_NS, 0.5, 0, SC_NS, 0 );	///<クロック信号生成
	sc_signal<bool> nrst;								///<リセット信号の生成
	sc_signal<sc_uint<32>> a;							///<出力信号
	sc_signal<sc_uint<32>> b;							///<出力信号
	sc_signal<sc_uint<32>> c;							///<出力信号
	sc_signal<sc_uint<32>> cthread_cc( "cthread_cc" );					///<出力信号
	sc_signal<sc_uint<32>> mul_c( "mul_c" );					///<出力信号

	//モジュールインスタンス生成
	adder adder1("adder1");

	//各ポートの接続
	adder1.clk(clk);
	adder1.nrst(nrst);
	adder1.a(a);
	adder1.b(b);
	adder1.c(c);
	adder1.cthread_cc(cthread_cc);
	adder1.mul_c(mul_c);

	sc_start( SC_ZERO_TIME );

	nrst.write( false );
	sc_start( 6, SC_NS);
	nrst.write( true );
	
	int i;
	for( i = 0; i < 10; ++i ){
		a.write( i );
		b.write( i * 100 );
		sc_start(10, SC_NS);
	}
	
	sc_close_vcd_trace_file(trace_f);
	return 0;
}
