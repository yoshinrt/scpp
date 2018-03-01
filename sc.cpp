#include <systemc.h>

SC_MODULE( adder ){
	
	sc_in_clk	clk;
	sc_in<bool>	nrst;
	
	sc_in<sc_uint<32> >	a;
	sc_in<sc_uint<32> >	b;
	
	sc_out<sc_uint<32> >	c;
	sc_out<sc_uint<32> >	cc;
	
	SC_CTOR( adder ){
		SC_CTHREAD( AdderCThread, clk.pos());
		reset_signal_is( nrst, false );
		
		SC_METHOD( AdderMethod );
		sensitive << a << b;
	}
	
	void AdderCThread( void ){
		c.write( 0 );
		wait();
		
		while( 1 ){
			c.write( a.read() + b.read());
			wait();
		}
	}
	
	void AdderMethod( void ){
		cc.write( a.read() + b.read());
	}
};

int sc_main(int argc, char* argv[])
{
	sc_clock clk( "clk", 10, SC_NS, 0.5, 0, SC_NS, 0 ); ///<クロック信号生成
	sc_signal<bool> nrst;																///<リセット信号の生成
	sc_signal<sc_uint<32> > a;																	///<出力信号
	sc_signal<sc_uint<32> > b;																	///<出力信号
	sc_signal<sc_uint<32> > c;																	///<出力信号
	sc_signal<sc_uint<32> > cc( "cc" );																	///<出力信号

	//モジュールインスタンス生成
	adder adder1("adder1");

	//各ポートの接続
	adder1.clk(clk);
	adder1.nrst(nrst);
	adder1.a(a);
	adder1.b(b);
	adder1.c(c);
	adder1.cc(cc);

	//トレースファイル関連
	sc_trace_file *trace_f;
	trace_f = sc_create_vcd_trace_file( "adder" );
	trace_f->set_time_unit( 1.0, SC_NS );
	sc_trace(trace_f, clk, "clk");
	sc_trace(trace_f, nrst, "nrst");
	sc_trace(trace_f, a, "a");
	sc_trace(trace_f, b, "b");
	sc_trace(trace_f, c, "c");
	sc_trace(trace_f, cc, cc.name());
	sc_trace(trace_f, adder1.cc, adder1.cc.name());
	
	sc_start( SC_ZERO_TIME );

	nrst = false;
	sc_start( 6, SC_NS);
	nrst = true;
	
	int i;
	for( i = 0; i < 10; ++i ){
		a.write( i );
		b.write( i * 100 );
		sc_start(10, SC_NS);
	}
	
	sc_close_vcd_trace_file(trace_f);
	return 0;
}