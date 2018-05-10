#include "sc.h"

sc_trace_file *trace_f;

#define repeat( n )	for( int i = 0; i < ( n ); ++i )
#define Wait( n )	repeat( n ) wait()

SC_MODULE( sim_top ){
	
	sc_in_clk	clk;
	sc_out<bool>	nrst;
	sc_out<sc_uint<32>>	a;
	sc_out<sc_uint<32>>	b;
	sc_in<sc_uint<32>>	c;
	sc_in<sc_uint<32>>	cthread_cc;
	sc_in<sc_uint<32>> mul_c;
	
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
	sc_signal<bool> nrst;								///<リセット信号の生成
	sc_signal<sc_uint<32>> a;							///<出力信号
	sc_signal<sc_uint<32>> b;							///<出力信号
	sc_signal<sc_uint<32>> c;							///<出力信号
	sc_signal<sc_uint<32>> cthread_cc( "cthread_cc" );					///<出力信号
	sc_signal<sc_uint<32>> mul_c( "mul_c" );					///<出力信号
	
	//モジュールインスタンス生成
	adder *adder1 = new adder( "adder1" );
	adder1->clk(clk);
	adder1->nrst(nrst);
	adder1->a(a);
	adder1->b(b);
	adder1->c(c);
	adder1->cthread_cc(cthread_cc);
	adder1->mul_c(mul_c);
	
	sim_top *sim_top1 = new sim_top( "sim_top1" );
	sim_top1->clk(clk);
	sim_top1->nrst(nrst);
	sim_top1->a(a);
	sim_top1->b(b);
	sim_top1->c(c);
	sim_top1->cthread_cc(cthread_cc);
	sim_top1->mul_c(mul_c);
	
	sc_start( SC_ZERO_TIME );
	sc_start();
	
	sc_close_vcd_trace_file(trace_f);
	return 0;
}
