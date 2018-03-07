#!/usr/bin/perl -w

use strict 'vars';
use strict 'refs';

### FileReader クラス ########################################################

package FileReader;

sub new {
	my( $class, $File ) = @_;
	my $self;
	
	$self = {
		'Name'		=> undef,
		'RealName'	=> undef,
		'Line'		=> 0,
		'fp'		=> undef,
	};
	
	bless( $self, $class );
	
	$self->Open( $File ) if( $File );
	
	return $self;
}

sub Open {
	my $self = shift;
	( $self->{ Name }) = @_;
	$self->{ RealName } = $self->{ Name };
	
	open( $self->{ fp }, "<" . $self->{ Name }) || die( "can't open file $self->{ Name }\n" );
	$self->{ Line } = 0;
}

sub Close {
	my $self = shift;
	close( $self->{ fp });
	$self->{ fp } = undef;
}

sub GetLine {
	my $self = shift;
	local $_;
	
	my $fp = $self->{ fp };
	while( <$fp> ){
		if( /^#\s*(\d+)\s*"(.+)"/ ){
			$self->{ Name } = $2;
			$self->{ Line } = $1 - 1;
			next;
		}
		
		++$self->{ Line };
		last;
	}
	
	return $_;
}

package main;

### C プリプロセッサを通す ###################################################

sub ConvertSafeStr {
	local( $_ ) = @_;
	
	s/\\(.)/sprintf( "\\x%02X", ord( $1 ))/ge;
	s/(["'\{\}\<\>\[\]\(\)])/sprintf( "\\x%02X", ord( $1 ))/ge;
	
	$_;
}

sub CPreprocessor {
	my( $File, $CppOpt ) = @_;
	local( $_ );
	
	my $fpIn;
	my $fpOut;
	
	open( $fpIn, "< $File" );
	open( $fpOut, "| cpp $CppOpt > $File.tmp" );
	
	print( $fpOut "# 1 \"$File\"\n" );
	
	while( <$fpIn> ){
		s@(#\s*include\s*\<)@//$1@;
		
		if( !/^\s*#/ ){
			s/"((?:\\\\|\\"|[^"])*)"/'"' . ConvertSafeStr( $1 ) . '"'/ge;
			s/'((?:\\\\|\\'|[^'])*)'/"'" . ConvertSafeStr( $1 ) . "'"/ge;
		}
		print( $fpOut $_ );
	}
	
	close( $fpIn );
	close( $fpOut );
}

##############################################################################

CPreprocessor( "sc.cpp", "'-DSCPP_AUTO_CONNECT(a)=1'" );
my $file = FileReader->new( "sc.cpp.tmp" );

while( $_ = $file->GetLine ){
	print "$file->{ Name }($file->{ Line }): $_";
}
