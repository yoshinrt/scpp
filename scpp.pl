#!/usr/bin/perl -w

use strict 'vars';
use strict 'refs';

### FileReader ���饹 ########################################################

package FileReader;

my $enum = 0;
my $BLKMODE_NORMAL	= $enum++;	# �֥�å���
my $BLKMODE_REPEAT	= $enum++;	# repeat �֥�å�
my $BLKMODE_PERL	= $enum++;	# perl �֥�å�
my $BLKMODE_IF		= $enum++;	# if �֥�å�
my $BLKMODE_ELSE	= $enum++;	# else �֥�å�

my $BlockNoOutput	= 0;
my $BlockRepeat		= 0;
my $ResetLinePos	= 0;
my $VppStage		= 0;
my @CommentPool;

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
	$self->{ Line }		= 0;
	
	open( $self->{ fp }, "<" . $self->{ Name }) || die( "can't open file $self->{ Name }\n" );
}

sub Close {
	my $self = shift;
	close( $self->{ fp });
	$self->{ fp } = undef;
}

### 1���ɤ� #################################################################

sub ReadLine {
	my $self = shift;
	
	local $_ = ReadLineSub( $self );
	
	my( $Cnt );
	my( $Line );
	my( $LineCnt ) = $self->{ Line };
	
	while( m@(//#?|/\*|(?<!\\)")@ ){
		$Cnt = $#CommentPool + 1;
		
		if( $1 eq '//' ){
			push( @CommentPool, $1 ) if( s#(//.*)#<__COMMENT_${Cnt}__># && !$VppStage );
		}elsif( $1 eq '"' ){
			if( s/((?<!\\)".*?(?<!\\)")/<__STRING_${Cnt}__>/ ){
				push( @CommentPool, $1 ) if( !$VppStage );
			}else{
				Error( 'unterminated "' );
				s/"//;
			}
		}elsif( s#(/\*.*?\*/)#<__COMMENT_${Cnt}__>#s ){
			# /* ... */ ���Ȥ�ȯ�����줿�顤�ִ�
			push( @CommentPool, $1 ) if( !$VppStage );
			$ResetLinePos = $.;
		}else{
			# /* ... */ ���Ȥ�ȯ������ʤ��Τǡ�ȯ�������ޤǹ� cat
			if( !( $Line = ReadLineSub( $_[ 0 ] ))){
				Error( 'unterminated */', $LineCnt );
				last;
			}
			$_ .= $Line;
		}
	}
	
	$_;
}

sub ReadLineSub {
	my $self = shift;
	local( $_ );
	
	my $fp = $self->{ fp };
	
	while( <$fp> ){
		++$self->{ Line };
		
		if( $VppStage && /^#\s*(\d+)\s+"(.*)"/ ){
			# cpp �� # 10 "hoge.c" �Ȥ�
			$self->{ Name } = $2;
			$self->{ Line } = $1 - 1;
		}elsif( m@^\s*//#@ ){
			$ResetLinePos = $.;
			next;
		}else{
			s@\s*//#.*@@;
			last;
		}
	}
	return '' if( !defined( $_ ));
	$_;
}

#### C �ץ�ץ��å� ########################################################

sub CPreprocessor {
	my $self = shift;
	
	my( $BlockMode, $bNoOutput ) = @_;
	$BlockMode	= 0 if( !defined( $BlockMode ));
	$bNoOutput	= 0 if( !defined( $bNoOutput ));
	local( $_ );
	
	$BlockNoOutput	<<= 1;
	$BlockNoOutput	|= $bNoOutput;
	$BlockRepeat	<<= 1;
	$BlockRepeat	|= ( $BlockMode == $BLKMODE_REPEAT ? 1 : 0 );
	
	my $Line;
	my $i;
	my $BlockMode2;
	my $LineCnt = $self->{ Line };
	
	while( $_ = $self->ReadLine()){
		
		if( /^\s*#\s*(?:ifdef|ifndef|if|elif|else|endif|repeat|foreach|endrep|perl|endperl|define|undef|include|require)\b/ ){
			
			# \ �ǽ���äƤ���Ԥ�Ϣ��
			while( /\\$/ ){
				if( !( $Line = $self->ReadLine())){
					last;
				}
				$_ .= $Line;
			}
			
			$ResetLinePos = $self->{ Line };
			
			# \ ���
			s/[\t ]*\\[\x0D\x0A]+[\t ]*/ /g;
			s/\s+$//g;
			s/^\s*#\s*//;
			
			$_ = ExpandMacro( $_, $EX_REP | $EX_RMCOMMENT );
			
			# $DefineTbl{ $1 }{ args }:  >=0: ����  <0: ���Ѱ���  's': ñ��ޥ���
			# $DefineTbl{ $1 }{ macro }:  �ޥ����������
			
			if( /^ifdef\b(.*)/ ){
				$self->CPreprocessor( $BLKMODE_IF, !IfBlockEval( "defined $1" ));
			}elsif( /^ifndef\b(.*)/ ){
				$self->CPreprocessor( $BLKMODE_IF,  IfBlockEval( "defined $1" ));
			}elsif( /^if\b(.*)/ ){
				$self->CPreprocessor( $BLKMODE_IF, !IfBlockEval( $1 ));
			}elsif( /^elif\b(.*)/ ){
				if( $BlockMode != $BLKMODE_IF ){
					Error( "unexpected #elif" );
				}elsif( $bNoOutput ){
					# �ޤ����Ϥ��Ƥ��ʤ�
					$bNoOutput = !IfBlockEval( $1 );
					$BlockNoOutput &= ~1;
					$BlockNoOutput |= 1 if( $bNoOutput );
				}else{
					# �⤦���Ϥ���
					$BlockNoOutput |= 1;
				}
			}elsif( /^else\b/ ){
				# else
				if( $BlockMode != $BLKMODE_IF ){
					Error( "unexpected #else" );
				}elsif( $bNoOutput ){
					# �ޤ����Ϥ��Ƥ��ʤ�
					$bNoOutput = 0;
					$BlockNoOutput &= ~1;
				}else{
					# �⤦���Ϥ���
					$BlockNoOutput |= 1;
				}
			}elsif( /^endif\b/ ){
				# endif
				if(
					$BlockMode != $BLKMODE_IF &&
					$BlockMode != $BLKMODE_ELSE
				){
					Error( "unexpected #endif" );
				}else{
					last;
				}
			}elsif( /^repeat\s*($OpenClose)/ ){
				# repeat / endrepeat
				RepeatOutput( $1 );
			}elsif( /^foreach\s*($OpenClose)/ ){
				# foreach / endrepeat
				ForeachOutput( $1 );
			}elsif( /^endrep\b/ ){
				if( $BlockMode != $BLKMODE_REPEAT ){
					Error( "unexpected #endrep" );
				}else{
					last;
				}
			}elsif( /^perl\b/s ){
				# perl / endperl
				ExecPerl();
			}elsif( /^endperl\b/ ){
				if( $BlockMode != $BLKMODE_PERL ){
					Error( "unexpected #endperl" );
				}else{
					last;
				}
			}elsif( !$BlockNoOutput ){
				if( /^define\s+($CSymbol)$/ ){
					# ̾���������
					AddCppMacro( $1 );
				}elsif( /^define\s+($CSymbol)\s+(.+)/ ){
					# ̾���������
					AddCppMacro( $1, $2 );
				}elsif( /^define\s+($CSymbol)($OpenClose)\s*(.*)/ ){
					# �ؿ��ޥ���
					my( $Name, $ArgList, $Macro ) = ( $1, $2, $3 );
					
					# ArgList ������ʬ��
					$ArgList =~ s/^\(\s*//;
					$ArgList =~ s/\s*\)$//;
					my( @ArgList ) = split( /\s*,\s*/, $ArgList );
					
					# �ޥ�����ΰ������ü�ʸ�����ִ�
					my $ArgNum = $#ArgList + 1;
					
					for( $i = 0; $i <= $#ArgList; ++$i ){
						if( $i == $#ArgList && $ArgList[ $i ] eq '...' ){
							$ArgNum = -$ArgNum;
							last;
						}
						$Macro =~ s/\b$ArgList[ $i ]\b/<__ARG_${i}__>/g;
					}
					
					AddCppMacro( $Name, $Macro, $ArgNum );
				}elsif( /^undef\s+($CSymbol)$/ ){
					# undef
					delete( $DefineTbl{ $1 } );
				}elsif( /^include\s*(.*)/ ){
					Include( $1 );
				}elsif( /^require\s+(.*)/ ){
					Require( ExpandMacro( $1, $EX_INTFUNC | $EX_STR | $EX_RMCOMMENT ));
				}elsif( !$BlockNoOutput ){
					PrintRTL( ExpandMacro( $_, $EX_CPP | $EX_REP ));
				}
			}
		}elsif( !$BlockNoOutput ){
			PrintRTL( ExpandMacro( $_, $EX_CPP | $EX_REP ));
		}
	}
	
	if( $_ eq '' && $BlockMode != $BLKMODE_NORMAL ){
		if(     $BlockMode == $BLKMODE_REPEAT	){ Error( "unterminated #repeat",	$LineCnt );
		}elsif( $BlockMode == $BLKMODE_PERL		){ Error( "unterminated #perl",		$LineCnt );
		}elsif( $BlockMode == $BLKMODE_IF		){ Error( "unterminated #if",		$LineCnt );
		}elsif( $BlockMode == $BLKMODE_ELSE		){ Error( "unterminated #else",		$LineCnt );
		}
	}
	
	$BlockNoOutput	>>= 1;
	$BlockRepeat	>>= 1;
}

## C �ץ�ץ��å����̤� ###################################################

package main;

sub ConvertSafeStr {
	local( $_ ) = @_;
	
	s/\\(.)/sprintf( "\\x%02X", ord( $1 ))/ge;
	s/(["'\{\}\<\>\[\]\(\)])/sprintf( "\\x%02X", ord( $1 ))/ge;
	
	$_;
}

sub _CPreprocessor {
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

while( $_ = $file->ReadLine ){
	print "$file->{ Name }($file->{ Line }): $_";
}
