#include "sc.h"

// $ScppCthread( clk.pos(), nrst, false )
void adder::AdderCThread( void ){
	c.write( 0 );
	wait();
	
	while( 1 ){
		c.write( a.read() + b.read());
		wait();
	}
}
