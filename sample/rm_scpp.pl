#!/usr/bin/perl -w

undef $/;
mkdir( "bak", 0755 );

foreach $File ( @ARGV ){
	open( $fp, "<$File" );
	$tmp = $_ = <$fp>;
	close $fp;
	
	s#(/\*\s*\$Scpp.+?)\s+Begin\b.*?\$ScppEnd\b#$1 */#gs;
	s#(\$Scpp.+?)\s+Begin\b.*?\$ScppEnd\b#$1#gs;
	
	if( $tmp ne $_ ){
		rename( $File, "bak/$File" );
		open( $fp, "> $File" );
		print $fp $_;
		close( $fp );
	}
}
