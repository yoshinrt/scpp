#!/usr/bin/perl -w

use strict 'vars';
use strict 'refs';

### C プリプロセッサを通す ###################################################

sub CPreprocessor {
	my( $File, $CppOpt ) = @_;
	local( $_ );
	
	my $fpIn;
	my $fpOut;
	
	open( $fpIn, "< $File" );
	open( $fpOut, "| cpp $CppOpt > $File.tmp.cpp" );
	
	print( $fpOut "# 1 \"$File\"\n" );
	
	while( <$fpIn> ){
		s@(#\s*include\s*\<)@//$1@;
		
		s@//#\s*@SCPP_@g;
		
		if( !/^\s*#/ ){
			s/"((?:\\\\|\\"|[^"])*)"/ STRING /g;
			s/'((?:\\\\|\\'|[^'])*)'/ CHAR /g;
		}
		print( $fpOut $_ );
	}
	
	close( $fpIn );
	close( $fpOut );
}

##############################################################################

CPreprocessor( "sc.cpp", "" );
