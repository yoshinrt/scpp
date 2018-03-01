#ifndef _SIG_TRACE_H_
#define _SIG_TRACE_H_

template <class T>
class CSignalTrace : public T {
  public:
	CSignalTrace(){
		printf( "%s\n", T::name());
	}
	
	operator T() const{ return T( *this ); }
};

/*
#define sc_in_clk_trc( name )		CSignalTrace<sc_in_clk, #name> name
#define sc_in_trc( type, name )		CSignalTrace<sc_in<type >, #name> name
#define sc_out_trc( type, name )	CSignalTrace<sc_out<type >, #name> name
#define sc_signal_trc( type, name )	CSignalTrace<sc_signal<type >, #name> name
*/
#define sc_in_clk_trc( name )		CSignalTrace<sc_in_clk > name
#define sc_in_trc( type, name )		CSignalTrace<sc_in<type > > name
#define sc_out_trc( type, name )	CSignalTrace<sc_out<type > > name
#define sc_signal_trc( type, name )	CSignalTrace<sc_signal<type > > name

#endif
