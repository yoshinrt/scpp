#include "sc.h"

sc_trace_file *trace_f;

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
