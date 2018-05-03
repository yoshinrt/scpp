#!/usr/bin/perl -w

##############################################################################
#
#		scpp -- SystemC preprocessor
#		Copyright(C) by DDS
#
##############################################################################

use strict 'vars';
use strict 'refs';

my $enum = 1;
my $ATTR_REF		= $enum;				# wire �����Ȥ��줿
my $ATTR_FIX		= ( $enum <<= 1 );		# wire �˽��Ϥ��줿
my $ATTR_BYDIR		= ( $enum <<= 1 );		# inout ����³���줿
my $ATTR_IN			= ( $enum <<= 1 );		# ���� I
my $ATTR_OUT		= ( $enum <<= 1 );		# ���� O
my $ATTR_INOUT		= ( $enum <<= 1 );		# ���� IO
my $ATTR_WIRE		= ( $enum <<= 1 );		# ���� W
my $ATTR_MD			= ( $enum <<= 1 );		# multiple drv ( �ٹ����� )
my $ATTR_DEF		= ( $enum <<= 1 );		# �ݡ��ȡ���������Ѥ�
my $ATTR_DC_WEAK_W	= ( $enum <<= 1 );		# Bus Size �ϼ��ο���ٹ������
my $ATTR_WEAK_W		= ( $enum <<= 1 );		# Bus Size �ϼ��ο���
my $ATTR_USED		= ( $enum <<= 1 );		# ���� template �����Ѥ��줿
my $ATTR_IGNORE		= ( $enum <<= 1 );		# `ifdef �ڤ���������̵���ݡ��Ȥ�̵�뤹����
my $ATTR_NC			= ( $enum <<= 1 );		# ���� 0 ���ꡤ���� open

$enum = 0;
my $BLKMODE_NORMAL	= $enum++;	# �֥�å���
my $BLKMODE_REPEAT	= $enum++;	# repeat �֥�å�
my $BLKMODE_PERL	= $enum++;	# perl �֥�å�
my $BLKMODE_IF		= $enum++;	# if �֥�å�
my $BLKMODE_ELSE	= $enum++;	# else �֥�å�

$enum = 1;
my $EX_CPP			= $enum;		# CPP �ޥ���Ÿ��
my $EX_REP			= $enum <<= 1;	# repeat �ޥ���Ÿ��
my $EX_INTFUNC		= $enum <<= 1;	# sizeof, typeof Ÿ��
my $EX_STR			= $enum <<= 1;	# ʸ�����ƥ��
my $EX_RMSTR		= $enum <<= 1;	# ʸ�����ƥ����
my $EX_COMMENT		= $enum <<= 1;	# ������
my $EX_RMCOMMENT	= $enum <<= 1;	# �����Ⱥ��
my $EX_NOREAD		= $enum <<= 1;	# $fpIn �����ɲ��ɤ߹��ߤ��ʤ�
my $EX_NOSIGINFO	= $enum <<= 1;	# %WireList �����Բ�

$enum = 1;
my $MODMODE_NONE	= 0;
my $MODMODE_NORMAL	= $enum;
my $MODMODE_TEST	= $enum <<= 1;
my $MODMODE_INC		= $enum <<= 1;
my $MODMODE_TESTINC	= $MODMODE_TEST | $MODMODE_INC;
my $MODMODE_PROGRAM	= $enum <<= 1;

my $CSymbol			= qr/\b[_a-zA-Z]\w*\b/;
my $CSymbol2		= qr/\b[_a-zA-Z\$]\w*\b/;
my $SigTypeDef		= qr/\b(?:parameter|wire|reg|input|output(?:\s+reg)?|inout)\b/;
my $DefSkelPort		= "(.*)";
my $DefSkelWire		= "\$1";

my $tab0 = 4 * 2;
my $tab1 = 4 * 7;
my $tab2 = 4 * 13;

my $ErrorCnt = 0;
my $TabWidth = 4;	# ������

my $TabWidthType	= 12;	# input / output ��
my $TabWidthBit		= 8;	# [xx:xx]

my $OpenClose;
   $OpenClose		= qr/\([^()]*(?:(??{$OpenClose})[^()]*)*\)/;
my $OpenCloseArg	= qr/[^(),]*(?:(??{$OpenClose})[^(),]*)*/;
my $Debug	= 0;

my $SEEK_SET = 0;

my( $fpIn, $fpOut, $fpList );
my( $DefFile, $DstFile, $ListFile, $CppFile );
my $PrintBuf;
my $RTLBuf;
my $PerlBuf;
my $ModuleName;
my $ExpandTab;
my $BlockNoOutput	= 0;
my $BlockRepeat		= 0;

my $ResetLinePos	= 0;
my $VppStage		= 0;
my $bPrevLineBlank	= 1;
my $CppOnly			= 0;
my $Deflize			= 0;
my @IncludeList;

# ����ơ��֥�ط�
my @WireList;
my %WireList;
my @SkelList;
my $iModuleMode;
my $PortDef;
my $ParamDef;
my %DefineTbl;

my @CommentPool = ();

main();
exit( $ErrorCnt != 0 );

### main procedure ###########################################################

sub main{
	local( $_ );
	
	if( $#ARGV < 0 ){
		print( "usage: vpp.pl [-vrE] [-I<path>] [-D<def>[=<val>]] [-tab<width>] <Def file>\n" );
		return;
	}
	
	# -DMACRO setup
	
	while( 1 ){
		$_ = $ARGV[ 0 ];
		
		if    ( /^-I(.*)/		){ push( @INC, $1 );
		}elsif( /^-D(.+?)=(.+)/	){ AddCppMacro( $1, $2 );
		}elsif( /^-D(.+)/		){ AddCppMacro( $1 );
		}elsif( /^-tab(.*)/		){ $ExpandTab = 1; $TabWidth = eval( $1 );
		}elsif( /^-/			){
			while( s/v// ){ ++$Debug; }
			$CppOnly = 1 if( /E/ );
			$Deflize = 1 if( /r/ );
		}else					 { last;
		}
		shift( @ARGV );
	}
	
	if( $Deflize ){
		Deflize( $ARGV[ 0 ]);
		return;
	}
	
	# tab ��Ĵ��
	$tab0 = $TabWidth * 2;
	
	# set up default file name
	
	$DefFile  = $ARGV[ 0 ];
	
	$DefFile =~ /(.*?)(\.def)?(\.[^\.]+)$/;
	
	$DstFile  = "$1$3";
	$DstFile  = "$1_top$3" if( $DstFile eq $DefFile );
	$ListFile = "$1.list";
	$CppFile  = $Debug ? "$1.cpp$3" : "$1.cpp$3.$$";
	
	$fpIn = CPreprocessor( $DefFile, $CppFile );
exit;
	
	if( $CppOnly ){
		while( <$fpIn> ){
			print( $Debug ? $_ : ExpandMacro( $_, $EX_STR | $EX_COMMENT ));
		}
	}else{
		# vpp
		
		unlink( $ListFile );
		
		$ExpandTab ?
			open( $fpOut, "| expand -$TabWidth > $DstFile" ) :
			open( $fpOut, "> $DstFile" );
		
		$VppStage = 1;
		MultiLineParser();
		
		close( $fpOut );
		close( $fpIn );
	}
	
	unlink( $CppFile );
}

### C �ץ�ץ��å� ########################################################

sub CPreprocessor {
	my( $InFile, $OutFile ) = @_;
	
	# expand $repeat
	if( !open( $fpIn, "< $InFile" )){
		Error( "can't open file \"$InFile\"" );
		return 1;
	}
	
	if( !open( $fpOut, "> $OutFile" )){
		Error( "can't open file \"$OutFile\"" );
		close( $fpIn );
		return 1;
	}
	
	ExpandRepeatOutput();
	
	if( $Debug >= 2 ){
		print( "=== macro ===\n" );
		foreach $_ ( sort keys %DefineTbl ){
			printf( "$_%s\t$DefineTbl{ $_ }{ macro }\n", $DefineTbl{ $_ }{ args } eq 's' ? '' : '()' );
		}
		print( "=== comment =\n" );
		print( join( "\n", @CommentPool ));
		print( "\n=============\n" );
	}
	undef( %DefineTbl );
	
	close( $fpOut );
	close( $fpIn );
	
	if( !open( $fpIn, "< $OutFile" )){
		Error( "can't open file \"$OutFile\"" );
		return 1;
	}
	
	return 0;
}

### 1���ɤ� #################################################################

sub ReadLine {
	local $_ = ReadLineSub( $_[ 0 ] );
	
	my( $Cnt );
	my( $Line );
	my( $LineCnt ) = $.;
	
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
	my( $fp ) = @_;
	local( $_ );
	
	while( <$fp> ){
		if( $VppStage && /^#\s*(\d+)\s+"(.*)"/ ){
			$. = $1 - 1;
			$DefFile = ( $2 eq "-" ) ? $ARGV[ 0 ] : $2;
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

# �ؿ��ޥ����Ѥ� ( ... ) �����
sub GetFuncArg {
	local $_;
	my $fp;
	( $fp, $_ ) = @_;
	my( $Line );
	
	while( !/^$OpenClose/ ){
		$ResetLinePos = $.;
		
		if( !( $Line = ReadLine( $fp ))){
			Error( "unmatched ')'" );
			last;
		}
		$_ .= $Line;
	}
	
	$_;
}

### Start of the module #####################################################

sub ExpandRepeatOutput {
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
	my $LineCnt = $.;
	
	while( $_ = ReadLine( $fpIn )){
		if( /^\s*#\s*(?:ifdef|ifndef|if|elif|else|endif|repeat|foreach|endrep|perl|endperl|define|undef|include|require)\b/ ){
			
			# \ �ǽ���äƤ���Ԥ�Ϣ��
			while( /\\$/ ){
				if( !( $Line = ReadLine( $fpIn ))){
					last;
				}
				$_ .= $Line;
			}
			
			$ResetLinePos = $.;
			
			# \ ���
			s/[\t ]*\\[\x0D\x0A]+[\t ]*/ /g;
			s/\s+$//g;
			s/^\s*#\s*//;
			
			$_ = ExpandMacro( $_, $EX_REP | $EX_RMCOMMENT );
			
			# $DefineTbl{ $1 }{ args }:  >=0: ����  <0: ���Ѱ���  's': ñ��ޥ���
			# $DefineTbl{ $1 }{ macro }:  �ޥ����������
			
			if( /^ifdef\b(.*)/ ){
				ExpandRepeatOutput( $BLKMODE_IF, !IfBlockEval( "defined $1" ));
			}elsif( /^ifndef\b(.*)/ ){
				ExpandRepeatOutput( $BLKMODE_IF,  IfBlockEval( "defined $1" ));
			}elsif( /^if\b(.*)/ ){
				ExpandRepeatOutput( $BLKMODE_IF, !IfBlockEval( $1 ));
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

### �ޥ���饤��ѡ��� #######################################################

sub MultiLineParser {
	local( $_ );
	my( $Line, $Word );
	
	while( $_ = ReadLine( $fpIn )){
		( $Word, $Line ) = GetWord(
			ExpandMacro( $_, $EX_INTFUNC | $EX_STR | $EX_RMCOMMENT )
		);
		
		if    ( $Word eq 'module'			){ StartModule( $Line, $MODMODE_NORMAL );
		}elsif( $Word eq 'module_inc'		){ StartModule( $Line, $MODMODE_INC );
		}elsif( $Word eq 'testmodule'		){ StartModule( $Line, $MODMODE_TEST );
		}elsif( $Word eq 'testmodule_inc'	){ StartModule( $Line, $MODMODE_TESTINC );
		}elsif( $Word eq 'endmodule'		){ EndModule( $_ );
		}elsif( $Word eq 'program'			){ StartModule( $Line, $MODMODE_PROGRAM | $MODMODE_NORMAL );
		}elsif( $Word eq 'program_inc'		){ StartModule( $Line, $MODMODE_PROGRAM | $MODMODE_INC );
		}elsif( $Word eq 'testprogram'		){ StartModule( $Line, $MODMODE_PROGRAM | $MODMODE_TEST );
		}elsif( $Word eq 'testprogram_inc'	){ StartModule( $Line, $MODMODE_PROGRAM | $MODMODE_TESTINC );
		}elsif( $Word eq 'endprogram'		){ EndModule( $_ );
		}elsif( $Word eq 'instance'			){ DefineInst( $Line );
		}elsif( $Word eq '$wire'			){ DefineDefWireSkel( $Line );
		}elsif( $Word eq '$header'			){ OutputHeader();
		}elsif( $Word eq '$AllInputs'		){ PrintAllInputs( $Line, $_ );
		}else{
			if( $Word =~ /^_(?:end)?(?:module|program)$/ ){
				$_ =~ s/\b_((?:end)?(?:module|program))\b/$1/;
			}
			PrintRTL( ExpandMacro( $_, $EX_INTFUNC | $EX_STR | $EX_COMMENT ));
		}
	}
}

### Start of the module #####################################################

sub StartModule{
	local( $_ );
	( $_, $iModuleMode ) = @_;
	
	my(
		@ModuleIO,
		@IOList,
		$InOut,
		$BitWidth,
		$Attr,
		$Port
	);
	
	# wire list �����
	
	@WireList	= ();
	%WireList	= ();
	$PortDef	= '';
	$ParamDef	= '';
	
	$PrintBuf	= \$RTLBuf;
	$RTLBuf		= "";
	
	( $ModuleName, $_ ) = GetWord( ExpandMacro( $_, $EX_INTFUNC | $EX_RMCOMMENT | $EX_NOREAD ));
	
	#PrintRTL( SkipToSemiColon( $_ ));
	#SkipToSemiColon( $_ );
	
	# module hoge #( ... ) ������ parameter ǧ��
	if( /^(\s*#)(\([\s\S]*)/ ){
		( $ParamDef, $_ ) = ( $1, "$2\n" );
		$_ = GetFuncArg( $fpIn, $_ );
		
		/^($OpenClose\s*)([\s\S]*)/;
		$ParamDef .= $1;
		$_ = $2;
	}
	
	# ); �ޤ��ɤ� �����ɤ᤿�餽���ݡ��ȥꥹ�ȤȤߤʤ�
	
	if( !/^\s*;/ ){
		while( $_ = ReadLine( $fpIn )){
			$_ = ExpandMacro( $_, $EX_INTFUNC );
			
			last if( /\s*\);/ );
			next if( /^\s*\(\s*$/ || /^#/ );
			
			s/\boutput\s*reg\b/output reg/;
			s/outreg/output reg/g;
			
			if( /^\s*($SigTypeDef)\s*(\[[^\]]+\])?\s*(.*)/ ){
				if( !defined( $2 )){
					$_ = "\t" .
						TabSpace( $1, $TabWidthType, $TabWidth ) .
						TabSpace( '', $TabWidthBit,  $TabWidth ) .
						$3 . "\n";
				}else{
					$_ = "\t" .
						TabSpace( $1, $TabWidthType, $TabWidth ) .
						TabSpace( $2, $TabWidthBit,  $TabWidth ) .
						$3 . "\n";
				}
			}else{
				s|^[ \t]*|\t|;
			}
			$PortDef .= $_;
		}
		
		if( $PortDef =~ /$SigTypeDef/ ){
			$PortDef =~ s/;([^;]*)$/$1/;
			$PortDef =~ s/;/,/g;
			$PortDef = ExpandMacro( $PortDef, $EX_STR | $EX_COMMENT | $EX_NOREAD );
		}else{
			$PortDef = '';
		}
	}
	
	RegisterModuleIO( $ModuleName, $CppFile, $ARGV[ 0 ]);
}

# �� module �� wire / port �ꥹ�Ȥ�get

sub RegisterModuleIO {
	local $_;
	my( $ModuleName, $CppFile, $DispFile ) = @_;
	my( $InOut, $BitWidth, @IOList, $Port, $Attr );
	
	my @ModuleIO = GetModuleIO( $ModuleName, $CppFile, $DispFile );
	
	# input/output ʸ 1 �Ԥ��Ȥν���
	
	while( $_ = shift( @ModuleIO )){
		( $InOut, $BitWidth, @IOList )	= split( /\t/, $_ );
		
		while( $Port = shift( @IOList )){
			$Attr = $InOut eq "input"	? $ATTR_DEF | $ATTR_IN		:
					$InOut eq "output"	? $ATTR_DEF | $ATTR_OUT		:
					$InOut eq "inout"	? $ATTR_DEF | $ATTR_INOUT	:
					$InOut eq "wire"	? $ATTR_DEF | $ATTR_WIRE	:
					$InOut eq "reg"		? $ATTR_DEF | $ATTR_WIRE | $ATTR_REF	:
					$InOut eq "assign"	? $ATTR_FIX | $ATTR_WEAK_W	: 0;
			
			if( $BitWidth eq '?' ){
				$Attr |= $ATTR_WEAK_W;
			}
			
			RegisterWire( $Port, $BitWidth, $Attr, $ModuleName );
		}
	}
}

### End of the module ########################################################

sub EndModule{
	local( $_ ) = @_;
	my(
		$Type,
		$bFirst,
		$Wire
	);
	
	my( $MSB, $LSB, $MSB_Drv, $LSB_Drv );
	
	# expand bus
	
	ExpandBus();
	
	PrintRTL( '//' ) if( $iModuleMode & $MODMODE_INC );
	PrintRTL( ExpandMacro( $_, $EX_STR | $EX_COMMENT ));
	undef( $PrintBuf );
	
	# module port �ꥹ�Ȥ����
	
	$bFirst = 1;
	PrintRTL( '//' ) if( $iModuleMode & $MODMODE_INC );
	PrintRTL(( $iModuleMode & $MODMODE_PROGRAM ? 'program' : 'module' ) . " $ModuleName" );
	
	if( $iModuleMode & $MODMODE_NORMAL ){
		
		my( $PortDef2 ) = '';
		
		foreach $Wire ( @WireList ){
			$Type = QueryWireType( $Wire, 'd' );
			
			if( $Type eq "input" || $Type eq "output" || $Type eq "inout" ){
				$PortDef2 .= FormatSigDef( $Type, $Wire->{ width }, $Wire->{ name }, ',' );
			}
		}
		
		if( $PortDef || $PortDef2 ){
			$PortDef .= "\t,\n" if( $PortDef && $PortDef2 );
			$PortDef2 =~ s/,([^,]*)$/$1/;
			PrintRTL( "$ParamDef(\n$PortDef$PortDef2)" );
		}
	}
	
	PrintRTL( ";\n" );
	
	# in/out/reg/wire �������
	
	foreach $Wire ( @WireList ){
		if(( $Type = QueryWireType( $Wire, "d" )) ne "" ){
			
			if( $iModuleMode & $MODMODE_NORMAL ){
				next if( $Type eq "input" || $Type eq "output" || $Type eq "inout" );
			}elsif( $iModuleMode & $MODMODE_TEST ){
				$Type = "reg"  if( $Type eq "input" );
				$Type = "wire" if( $Type eq "output" || $Type eq "inout" );
			}elsif( $iModuleMode & $MODMODE_INC ){
				# ��ƥ��ȥ⥸�塼��� include �⡼�ɤǤϡ��Ȥꤢ�������� wire �ˤ���
				$Type = 'wire';
			}
			
			PrintRTL( FormatSigDef( $Type, $Wire->{ width }, $Wire->{ name }, ';' ));
		}
	}
	
	# buf �ˤ���Ƥ������Ҥ�ե�å���
	
	print( $fpOut $RTLBuf );
	$RTLBuf = "";
	
	# wire �ꥹ�Ȥ���� for debug
	OutputWireList();
	
	$iModuleMode = $MODMODE_NONE;
}

sub FormatSigDef {
	local $_;
	my( $Type, $Width, $Name, $eol ) = @_;
	
	$_ = "\t" . TabSpace( $Type, $TabWidthType, $TabWidth );
	
	if( $Width eq "" || $Width =~ /^\[/ ){
		# bit ����ʤ� or [xx:xx]
		$_ .= TabSpace( $Width, $TabWidthBit, $TabWidth );
	}else{
		# 10:2 �Ȥ�
		$_ .= TabSpace( FormatBusWidth( $Width ), $TabWidthBit, $TabWidth );
	}
	
	$_ .= "$Name$eol\n";
}

### Evaluate #################################################################

sub Evaluate {
	local( $_ ) = @_;
	
	s/\$Eval\b//g;
	$_ = eval( $_ );
	Error( $@ ) if( $@ ne '' );
	return( $_ );
}

sub Evaluate2 {
	local( $_ ) = @_;
	local( @_ );
	
	s/\$Eval\b//g;
	@_ = eval( $_ );
	Error( $@ ) if( $@ ne '' );
	return( @_ );
}

### output normal line #######################################################

sub PrintRTL{
	local( $_ ) = @_;
	my( $tmp );
	
	# Case / FullCase ����
	s|\bC(asex?\s*\(.*\))|c$1 <__COMMENT_0__>|g;
	s|\bFullC(asex?\s*\(.*\))|c$1 <__COMMENT_1__>|g;
	
	if( $VppStage ){
		# ���԰���
		s/^([ \t]*\n)([ \t]*\n)+/$1/gm;
	}else{
		if( $ResetLinePos ){
			# �����Ϻ��򤬤狼��ʤ����ޤ��Х��äƤ뤫��
			if( $ResetLinePos == $. ){
				$_ .= sprintf( "# %d \"$DefFile\"\n", $. + 1 );
			}else{
				$_ = sprintf( "# %d \"$DefFile\"\n", $. ) . $_;
			}
			$ResetLinePos = 0;
		}
	}
	
	if( !( $VppStage && $bPrevLineBlank && /^\s*$/ )){
		if( defined( $PrintBuf )){
			$$PrintBuf .= $_;
		}else{
			print( $fpOut $_ );
		}
	}
	
	$bPrevLineBlank = /^\s*$/ if( $VppStage );
}

### read instance definition #################################################
# syntax:
#	instance <module name> [#(<params>)] <instance name> <module file> (
#		<port>	<wire>	<attr>
#		a(\d+)	aa[$1]			// �Х���«��
#		b		bb$n			// �Х�Ÿ����
#	);
#
#	���ȥ�ӥ塼��: <������><�ݡ��ȥ�����>
#	  ������:
#		M		Multiple drive �ٹ����������
#		B		bit width weakly defined �ٹ����������
#		U		tmpl isn't used �ٹ����������
#	  �ݡ��ȥ�����:
#		NP		reg/wire ������ʤ�
#		NC		Wire ��³���ʤ�
#		W		�ݡ��ȥ����פ���Ū�� wire �ˤ���
#		I		�ݡ��ȥ����פ���Ū�� input �ˤ���
#		O		�ݡ��ȥ����פ���Ū�� output �ˤ���
#		IO		�ݡ��ȥ����פ���Ū�� inout �ˤ���
#		*D		̵��
#
#		$l1 $u1	��ʸ������ʸ���Ѵ�

sub DefineInst{
	local( $_ ) = @_;
	my(
		$Port,
		$Wire,
		$WireBus,
		$Attr,
		
		@ModuleIO,
		@IOList,
		$InOut,
		$BitWidth,
		$BitWidthWire,
		
		$bFirst,
		$Len,
		
		$tmp,
		$tmp2
	);
	
	@SkelList = ();
	
	my( $LineNo ) = $.;
	
	if( /#\(/ && !/#$OpenClose/ ){
		/^(.*?#)(.*)/;
		$tmp = $1;
		$_ = $tmp . GetFuncArg( $fpIn, $2 . "\n" );
	}
	
	if( !/\s+([\w\d]+)(\s+#$OpenClose)?\s+(\S+)\s+"?(\S+)"?\s*([\(;])/s ){
		Error( "syntax error (instance)" );
		return;
	}
	
	# get module name, module inst name, module file
	
	my( $ModuleName, $ModuleParam, $ModuleInst, $ModuleFile ) = (
		$1, defined( $2 ) ? ExpandMacro( $2, $EX_STR | $EX_COMMENT ) : '', $3,
		ExpandEnv( $4 )
	);
	$ModuleParam = '' if( !defined( $ModuleParam ));
	$_ = $5;
	$ModuleInst =~ s/\*/$ModuleName/g;
	
	if( $ModuleFile eq "*" ){
		$ModuleFile = $CppFile;
	}
	
	# read port->wire tmpl list
	
	ReadSkelList() if( $_ eq "(" );
	
	# instance �� header �����
	
	PrintRTL( "\t$ModuleName$ModuleParam $ModuleInst" );
	$bFirst = 1;
	
	# get sub module's port list
	
	@ModuleIO = GetModuleIO( $ModuleName, $ModuleFile );
	
	# input/output ʸ 1 �Ԥ��Ȥν���
	
	while( $_ = shift( @ModuleIO )){
		
		( $InOut, $BitWidth, @IOList )	= split( /\t/, $_ );
		next if( $InOut !~ /^(?:input|output|inout)$/ );
		
		while( $Port = shift( @IOList )){
			( $Wire, $Attr ) = ConvPort2Wire( $Port, $BitWidth, $InOut );
			
			if( !( $Attr & $ATTR_NC )){
				next if( $Attr & $ATTR_IGNORE );
				
				# hoge(\d) --> hoge[$1] �к�
				
				$WireBus = $Wire;
				if( $WireBus  =~ /(.*)\[(\d+(?::\d+)?)\]$/ ){
					
					$WireBus		= $1;
					$BitWidthWire	= $2;
					$BitWidthWire	= $BitWidthWire =~ /^\d+$/ ? "$BitWidthWire:$BitWidthWire" : $BitWidthWire;
					
					# instance �� tmpl �����
					#  hoge  hoge[1] �ʤɤΤ褦�� wire ¦�� bit ���꤬
					# �Ĥ����Ȥ� wire �μºݤΥ��������狼��ʤ�����
					# ATTR_WEAK_W °����Ĥ���
					$Attr |= $ATTR_WEAK_W;
				}else{
					$BitWidthWire	= $BitWidth;
					
					# BusSize �� [BIT_DMEMADR-1:0] �ʤɤΤ褦�������ξ��
					# ���ΤȤ��� $ATTR_WEAK_W °����Ĥ���
					if( $BitWidth ne '' && $BitWidth !~ /^\d+:\d+$/ ){
						$Attr |= $ATTR_WEAK_W;
					}
				}
				
				# wire list ����Ͽ
				
				if( $Wire !~ /^\d/ ){
					$Attr |= ( $InOut eq "input" )	? $ATTR_REF		:
							 ( $InOut eq "output" )	? $ATTR_FIX		:
													  $ATTR_BYDIR	;
					
					# wire ̾����
					
					$WireBus =~ s/\d+'[hdob]\d+//g;
					$WireBus =~ s/[\s{}]//g;
					$WireBus =~ s/\b\d+\b//g;
					
					@_ = split( /,+/, $WireBus );
					
					if( $#_ > 0 ){
						# { ... , ... } ����concat ���椬��³����Ƥ���
						foreach $WireBus ( @_ ){
							next if( $WireBus =~ /^\d/ ); # ��������å�
							$WireBus =~ s/\[.*\]//;
							next if( $WireBus eq '' );
							RegisterWire(
								$WireBus,
								'?',
								$Attr |= $ATTR_WEAK_W,
								$ModuleName
							);
						}
					}else{
						RegisterWire(
							$WireBus,
							$BitWidthWire,
							$Attr,
							$ModuleName
						) if( $WireBus ne '' );
					}
				}elsif( $Wire =~ /^\d+$/ ){
					# �������������ꤵ�줿��硤bit��ɽ����Ĥ���
					$Wire = sprintf( "%d'd$Wire", GetBusWidth2( $BitWidth ));
				}
			}
			
			# .hoge( hoge ), �� list �����
			
			PrintRTL( $bFirst ? "(\n" : ",\n" );
			$bFirst = 0;
			
			$tmp  = "\t" x (( $tab0 + $TabWidth - 1 ) / $TabWidth );
			$Len  = $tab0;
			
			$Wire =~ s/\$n//g;		#z $n �κ��
			$tmp .= ".$Port";
			$Len += length( $Port ) + 1;
			$tmp .= "\t" x (( $tab1 - $Len + $TabWidth - 1 ) / $TabWidth );
			$Len  = $tab1;
			
			$tmp .= "( $Wire";
			$Len += length( $Wire ) + 2;
			
			$tmp .= "\t" x (( $tab2 - $Len + $TabWidth - 1 ) / $TabWidth );
			$Len  = $tab2;
			
			$tmp .= ")";
			
			PrintRTL( "$tmp" );
		}
	}
	
	# instance �� footer �����
	
	PrintRTL( "\n\t)" ) if( !$bFirst );
	PrintRTL( ";\n" );
	
	# SkelList ̤���ѷٹ�
	
	WarnUnusedSkelList( $ModuleInst, $LineNo );
}

### search module & get IO definition ########################################

sub GetModuleIO{
	
	local $_;
	my( $ModuleName, $ModuleFile, $ModuleFileDisp ) = @_;
	my( $Buf, $bFound, $fp );
	
	$ModuleFileDisp = $ModuleFile if( !defined( $ModuleFileDisp ));
	
	$bFound = 0;
	
	if( !open( $fp, "< $ModuleFile" )){
		Error( "can't open file \"$ModuleFile\"" );
		return( "" );
	}
	
	# module ����Ƭ��õ��
	
	while( $_ = ReadLine( $fp )){
		if( $bFound ){
			# module ������
			last if( /\bend(?:module|program)\b/ );
			$Buf .= ExpandMacro( $_, $EX_INTFUNC | $EX_RMSTR | $EX_RMCOMMENT | $EX_NOSIGINFO );
		}else{
			# module ��ޤ����Ĥ��Ƥ��ʤ�
			if( /\b(?:test)?(?:module|program)(?:_inc)?\s+(.+)/ ){
				$_ = ExpandMacro( $1, $EX_INTFUNC | $EX_NOREAD | $EX_NOSIGINFO );
				$bFound = 1 if( /^$ModuleName\b/ );
			}
		}
	}
	
	close( $fp );
	
	if( !$bFound ){
		Error( "can't find module \"$ModuleName\@$ModuleFile\"" );
		return( "" );
	}
	
	$_ = $Buf;
	
	# delete comment
	s/\btask\b.*?\bendtask\b//gs;
	s/\bfunction\b.*?\bendfunction\b//gs;
	s/^\s*`.*//g;
	
	# delete \n
	s/[\x0D\x0A\t ]+/ /g;
	
	# split
	#print if( $Debug );
	s/\boutreg\b/output reg/g;
	s/\b((?:in|out)put)\s+wire\b/$1/g;
	s/($SigTypeDef)/\n$1/g;
	s/ *[;\)].*//g;
	
	# port �ʳ�����
	s/(.*)/DeleteExceptPort($1)/ge;
	s/ *\n+/\n/g;
	s/^\n//g;
	s/\n$//g;
	#print( "$ModuleName--------\n$_\n" ); # if( $Debug );
	
	return( split( /\n/, $_ ));
}

sub DeleteExceptPort{
	local( $_ ) = @_;
	my( $tmp );
	
	s/\boutput\s+reg\b/output/g;
	
	if( /^($SigTypeDef)\s*([\s\S]*)/ ){
		
		my( $Type ) = $1 eq 'parameter' ? 'wire' : $1;
		my( $Width ) = '';
		
		$_ = $2;
		
		# �Х��������λ��� [?] �Ȥ�����Τ���
		if( /^\[(.+?)\]\s*([\s\S]*)/ ){
			( $_, $tmp ) = ( $1, $2 );
			
			s/^\s+//;
			s/\s+$//;
			s/\s+/ /g;
			s/\s*:\s*/:/;
			
			( $Width, $_ ) = ( $_, $tmp );
		}
		
		s/\[.*?\]//g;	# 2��������θ������� [...] ����
		s/\s*=.*//g;	# wire hoge = hoge �� = �ʹߤ���
		
		s/[\s:,]+$//;
		s/[ ;,]+/\t/g;
		
		$_ = "$Type\t$Width\t$_";
		
	}elsif( /^assign\b/ ){
		# assign �Υ磻�䡼�ϡ�= ľ���μ��̻Ҥ����
		s/\s*=.*//g;
		/\s($CSymbol)$/;
		$_ = "assign\t?\t$1";
	}else{
		$_ = '';
	}
	
	return( $_ );
}

### get word #################################################################

sub GetWord{
	local( $_ ) = @_;
	
	s/\/\/.*//g;	# remove comment
	
	return( $1, $2 ) if( /^\s*([\w\d\$]+)(.*)/ || /^\s*(.)(.*)/ );
	return ( '', $_ );
}

### print error msg ##########################################################

sub Error{
	my( $Msg, $LineNo ) = @_;
	PrintDiagMsg( $Msg, $LineNo );
	++$ErrorCnt;
}

sub Warning{
	my( $Msg, $LineNo ) = @_;
	PrintDiagMsg( "Warning: $Msg", $LineNo );
}

sub PrintDiagMsg {
	local $_;
	my $LineNo;
	( $_, $LineNo ) = @_;
	
	if( $#IncludeList >= 0 ){
		foreach $_ ( @IncludeList ){
			print( "...included at $_->{ FileName }($_->{ LineCnt }):\n" );
		}
	}
	
	printf( "$DefFile(%d): $_\n", $LineNo || $. );
}

### define default port --> wire name ########################################

sub DefineDefWireSkel{
	local( $_ ) = @_;
	
	if( /\s*(\S+)\s+(\S+)/ ){
		$DefSkelPort = $1;
		$DefSkelWire = $2;
	}else{
		Error( "syntax error (template)" );
	}
}

### output header ############################################################

sub OutputHeader{
	
	my( $sec, $min, $hour, $mday, $mon, $year ) = localtime( time );
	my( $DateStr ) =
		sprintf( "%d/%02d/%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec );
	
	local $_ = $DefFile;
	s/\..*//g;
	
	print( $fpOut <<EOF );
/*****************************************************************************

	$DstFile -- $_ module	generated by vpp.pl
	
	Date     : $DateStr
	Def file : $DefFile

*****************************************************************************/
EOF
}

### skip to semi colon #######################################################

sub SkipToSemiColon{
	
	local( $_ ) = @_;
	
	do{
		goto ExitLoop if( s/.*?;//g );
	}while( $_ = ReadLine( $fpIn ));
	
  ExitLoop:
	return( $_ );
}

### read port/wire tmpl list #################################################

sub ReadSkelList{
	
	local $_;
	my(
		$Port,
		$Wire,
		$Attr,
		$AttrLetter
	);
	
	while( $_ = ReadLine( $fpIn )){
		$_ = ExpandMacro( $_, $EX_INTFUNC | $EX_STR | $EX_RMCOMMENT );
		s/\/\/.*//;
		s/#.*//;
		next if( /^\s*$/ );
		last if( /^\s*\);/ );
		
		/^\s*(\S+)\s*(\S*)\s*(\S*)/;
		
		( $Port, $Wire, $AttrLetter ) = ( $1, $2, $3 );
		
		if( $Wire =~ /^[MBU]?(?:NP|NC|W|I|O|IO|U|\*D)$/ ){
			$AttrLetter = $Wire;
			$Wire = "";
		}
		
		# attr
		
		$Attr = 0;
		
		$Attr |= $ATTR_MD			if( $AttrLetter =~ /M/ );
		$Attr |= $ATTR_DC_WEAK_W	if( $AttrLetter =~ /B/ );
		$Attr |= $ATTR_USED			if( $AttrLetter =~ /U/ );
		$Attr |=
			( $AttrLetter =~ /NP$/ ) ? $ATTR_DEF	:
			( $AttrLetter =~ /NC$/ ) ? $ATTR_NC		:
			( $AttrLetter =~ /W$/  ) ? $ATTR_WIRE	:
			( $AttrLetter =~ /I$/  ) ? $ATTR_IN		:
			( $AttrLetter =~ /O$/  ) ? $ATTR_OUT	:
			( $AttrLetter =~ /IO$/ ) ? $ATTR_INOUT	:
			( $AttrLetter =~ /\*D$/ )  ? $ATTR_IGNORE	:
								0;
		
		push( @SkelList, {
			'port'	=> $Port,
			'wire'	=> $Wire,
			'attr'	=> $Attr,
		} );
	}
}

### tmpl list ̤���ѷٹ� #####################################################

sub WarnUnusedSkelList{
	
	my( $LineNo );
	local( $_ );
	( $_, $LineNo ) = @_;
	my( $Skel );
	
	foreach $Skel ( @SkelList ){
		if( !( $Skel->{ attr } & $ATTR_USED )){
			Warning( "unused template ( $Skel->{ port } --> $Skel->{ wire } \@ $_ )", $LineNo );
		}
	}
}

### convert port name to wire name ###########################################

sub ConvPort2Wire {
	
	my( $Port, $BitWidth, $InOut ) = @_;
	my(
		$SkelPort,
		$SkelWire,
		
		$Wire,
		$Attr,
		
		$Skel
	);
	
	$SkelPort = $DefSkelPort;
	$SkelWire = $DefSkelWire;
	$Attr	  = 0;
	
	foreach $Skel ( @SkelList ){
		# bit���� 0 �ʤΤ� SkelWire �� $n �����ä��顤
		# ����Ū�� hit �����ʤ�
		next if( $BitWidth eq '' && $Skel->{ wire } =~ /\$n/ );
		
		# Hit ����
		if( $Port =~ /^$Skel->{ port }$/ ){
			# port tmpl ���Ѥ��줿
			$Skel->{ attr } |= $ATTR_USED;
			
			$SkelPort = $Skel->{ port };
			$SkelWire = $Skel->{ wire };
			$Attr	  = $Skel->{ attr };
			
			# NC �ʤ�ꥹ�Ȥ���ʤ�
			
			if( $Attr & $ATTR_NC ){
				if( $InOut eq 'input' ){
					if( $BitWidth =~ /(\d+):(\d+)/ ){
						$BitWidth = $1 - $2 + 1;
					}elsif( $BitWidth eq '' ){
						$BitWidth = 1;
					}
					return( "${BitWidth}'d0", $Attr );
				}
				return( "", $Attr );
			}
			last;
		}
	}
	
	# $<n> ���ִ�
	if( $SkelWire eq "" ){
		$SkelPort = $DefSkelPort;
		$SkelWire = $DefSkelWire;
	}
	
	$Wire =  $SkelWire;
	$Port =~ /^$SkelPort$/;
	
	my( $grp ) = [ $1, $2, $3, $4, $5, $6, $7, $8, $9 ];
	$Wire =~ s/\$([lu]?\d)/ReplaceGroup( $1, $grp )/ge;
	
	return( $Wire, $Attr );
}

sub ReplaceGroup {
	my( $grp );
	( $_, $grp ) = @_;
	
	/([lu]?)(\d)/;
	$_ = $grp->[ $2 - 1 ];
	
	return	$1 eq 'l' ? lc( $_ ) :
			$1 eq 'u' ? uc( $_ ) : $_;
}

### wire ����Ͽ ##############################################################

sub RegisterWire{
	
	my( $Name, $BitWidth, $Attr, $ModuleName ) = @_;
	my( $Wire );
	
	my( $MSB0, $MSB1, $LSB0, $LSB1 );
	
	if( defined( $Wire = $WireList{ $Name } )){
		# ���Ǥ���Ͽ�Ѥ�
		
		# ATTR_WEAK_W �������� BitWidth �򹹿�����
		if(
			!( $Attr			& $ATTR_WEAK_W ) &&
			( $Wire->{ attr }	& $ATTR_WEAK_W )
		){
			# List �� Weak �ǡ��������Τ� Hard �ʤΤ�����
			$Wire->{ width } = $BitWidth;
			
			# list �� ATTR_WEAK_W °����ä�
			$Wire->{ attr } &= ~$ATTR_WEAK_W;
			
		}elsif(
			( $Attr				& $ATTR_WEAK_W ) &&
			( $Wire->{ attr }	& $ATTR_WEAK_W ) &&
			$Wire->{ width } =~ /^\d+:\d+$/ && $BitWidth =~ /^\d+:\d+$/
		){
			# List���������� �Ȥ�� Weak �ʤΤǡ��礭���ۤ���Ȥ�
			
			( $MSB0, $LSB0 ) = GetBusWidth( $Wire->{ width } );
			( $MSB1, $LSB1 ) = GetBusWidth( $BitWidth );
			
			$MSB0 = $MSB1 if( $MSB0 < $MSB1 );
			$LSB0 = $LSB1 if( $LSB0 > $LSB1 );
			
			$Wire->{ width } = $BitWidth = "$MSB0:$LSB0";
			
		}elsif(
			!( $Attr			& $ATTR_WEAK_W ) &&
			!( $Wire->{ attr }	& $ATTR_WEAK_W ) &&
			$Wire->{ width } =~ /^\d+:\d+$/ && $BitWidth =~ /^\d+:\d+$/
		){
			# ξ�� Hard �ʤΤǡ�����������äƤ���� size mismatch �ٹ�
			
			if( GetBusWidth2( $Wire->{ width } ) != GetBusWidth2( $BitWidth )){
				Warning( "unmatch port width ( $ModuleName.$Name $BitWidth != $Wire->{ width } )" );
			}
		}
		
		# ξ�� inout ���ʤ顤��Ͽ����ۤ��� REF ���ѹ�
		
		if( $Wire->{ attr } & $Attr & $ATTR_INOUT ){
			$Attr |= $ATTR_REF;
		}
		
		# multiple driver �ٹ�
		
		if(
			( $Wire->{ attr } & $Attr & $ATTR_FIX ) &&
			!( $Attr & $ATTR_MD )
		){
			Warning( "multiple driver ( wire : $Name )" );
		}
		
		$Wire->{ attr } |= ( $Attr & ~$ATTR_WEAK_W );
		
	}else{
		# ������Ͽ
		
		push( @WireList, $Wire = {
			'name'	=> $Name,
			'width'	=> $BitWidth,
			'attr'	=> $Attr
		} );
		
		$WireList{ $Name } = $Wire;
	}
}

### query wire type & returns "in/out/inout" #################################
# $Mode eq "d" �� in/out/wire ���ʸ�⡼��

sub QueryWireType{
	
	my( $Wire, $Mode ) = @_;
	my( $Attr ) = $Wire->{ attr };
	
	return( ''		 ) if( $Attr & $ATTR_DEF  && $Mode eq 'd' );
	return( 'input'	 ) if( $Attr & $ATTR_IN );
	return( 'output' ) if( $Attr & $ATTR_OUT );
	return( 'inout'	 ) if( $Attr & $ATTR_INOUT );
	return( 'wire'	 ) if( $Attr & $ATTR_WIRE );
	return( 'inout'	 ) if(( $Attr & ( $ATTR_BYDIR | $ATTR_REF | $ATTR_FIX )) == $ATTR_BYDIR );
	return( 'input'	 ) if(( $Attr & ( $ATTR_REF | $ATTR_FIX )) == $ATTR_REF );
	return( 'output' ) if(( $Attr & ( $ATTR_REF | $ATTR_FIX )) == $ATTR_FIX );
	return( 'wire'	 ) if(( $Attr & ( $ATTR_REF | $ATTR_FIX )) == ( $ATTR_REF | $ATTR_FIX ));
	
	return( '' );
}

### output wire list #########################################################

sub OutputWireList{
	
	my(
		@WireListBuf,
		
		$WireCntUnresolved,
		$WireCntAdded,
		$Attr,
		$Type,
		$Wire,
	);
	
	$WireCntUnresolved = 0;
	$WireCntAdded	   = 0;
	
	foreach $Wire ( @WireList ){
		
		$Attr = $Wire->{ attr };
		$Type = QueryWireType( $Wire, "" );
		
		$Type =	( $Type eq "input" )	? "I" :
				( $Type eq "output" )	? "O" :
				( $Type eq "inout" )	? "B" :
				( $Type eq "wire" )		? "W" :
										  "-" ;
		
		++$WireCntUnresolved if( !( $Attr & ( $ATTR_BYDIR | $ATTR_FIX | $ATTR_REF )));
		if( !( $Attr & $ATTR_DEF ) && ( $Type =~ /[IOB]/ )){
			++$WireCntAdded;
			Warning( "'$ModuleName.$Wire->{ name }' is undefined, generated automatically" )
				if( !( $iModuleMode & $MODMODE_TEST ));
		}
		
		push( @WireListBuf, (
			$Type .
			(( $Attr & $ATTR_DEF )		? "d" :
			 ( $Type =~ /[IOB]/ )		? "!" : "-" ) .
			(( $Attr & ( $ATTR_BYDIR | $ATTR_FIX | $ATTR_REF ))
										? "-" : "!" ) .
			(( $Attr & $ATTR_WIRE )		? "W" :
			 ( $Attr & $ATTR_INOUT )	? "B" :
			 ( $Attr & $ATTR_OUT )		? "O" :
			 ( $Attr & $ATTR_IN )		? "I" : "-" ) .
			(( $Attr & $ATTR_BYDIR )	? "B" : "-" ) .
			(( $Attr & $ATTR_FIX )		? "F" : "-" ) .
			(( $Attr & $ATTR_REF )		? "R" : "-" ) .
			"\t$Wire->{ width }\t$Wire->{ name }\n"
		));
		
		# bus width is weakly defined error
		#Warning( "Bus size is not fixed '$ModuleName.$Wire->{ name }'" )
		#	if(
		#		( $Wire->{ attr } & ( $ATTR_WEAK_W | $ATTR_DC_WEAK_W | $ATTR_DEF )) == $ATTR_WEAK_W &&
		#		( $iModuleMode & $MODMODE_TEST ) == 0
		#	);
	}
	
	if( $Debug ){
		@WireListBuf = sort( @WireListBuf );
		
		printf( "Wire info : Unresolved:%3d / Added:%3d ( $ModuleName\@$DefFile )\n",
			$WireCntUnresolved, $WireCntAdded );
		
		if( !open( $fpList, ">> $ListFile" )){
			Error( "can't open file \"$ListFile\"" );
			return;
		}
		
		print( $fpList "*** $ModuleName wire list ***\n" );
		print( $fpList @WireListBuf );
		close( $fpList );
	}
}

### expand bus ###############################################################

sub ExpandBus{
	
	my(
		$Name,
		$Attr,
		$BitWidth,
		$Wire
	);
	
	foreach $Wire ( @WireList ){
		if( $Wire->{ name } =~ /\$n/ && $Wire->{ width } ne "" ){
			
			# Ÿ�����٤��Х�
			
			$Name		= $Wire->{ name };
			$Attr		= $Wire->{ attr };
			$BitWidth	= $Wire->{ width };
			
			# FR wire �ʤ� F �Ȥߤʤ�
			
			if(( $Attr & ( $ATTR_FIX | $ATTR_REF )) == ( $ATTR_FIX | $ATTR_REF )){
				$Attr &= ~$ATTR_REF
			}
			
			if( $Attr & ( $ATTR_REF | $ATTR_BYDIR )){
				ExpandBus2( $Name, $BitWidth, $Attr, 'ref' );
			}
			
			if( $Attr & ( $ATTR_FIX | $ATTR_BYDIR )){
				ExpandBus2( $Name, $BitWidth, $Attr, 'fix' );
			}
			
			# List ����ν���
			
			$Wire->{ attr } |= ( $ATTR_REF | $ATTR_FIX );
		}
		
		$Wire->{ name } =~ s/\$n//g;
	}
}

sub ExpandBus2{
	
	my( $Wire, $BitWidth, $Attr, $Dir ) = @_;
	my(
		$WireNum,
		$WireBus,
		$uMSB, $uLSB
	);
	
	# print( "ExBus2>>$Wire, $BitWidth, $Dir\n" );
	$WireBus =  $Wire;
	$WireBus =~ s/\$n//g;
	
	# $BitWidth ���� MSB, LSB ����Ф�
	if( $BitWidth =~ /(\d+):(\d+)/ ){
		$uMSB = $1;
		$uLSB = $2;
	}else{
		$uMSB = $BitWidth;
		$uLSB = 0;
	}
	
	# assign HOGE = {
	
	PrintRTL( "\tassign " );
	PrintRTL( "$WireBus = " ) if( $Dir eq 'ref' );
	PrintRTL( "{\n" );
	
	# bus �γ� bit �����
	
	for( $BitWidth = $uMSB; $BitWidth >= $uLSB; --$BitWidth ){
		$WireNum = $Wire;
		$WireNum =~ s/\$n/$BitWidth/g;
		
		PrintRTL( "\t\t$WireNum" );
		PrintRTL( ",\n" ) if( $BitWidth );
		
		# child wire ����Ͽ
		
		RegisterWire( $WireNum, "", $Attr, $ModuleName );
	}
	
	# } = hoge;
	
	PrintRTL( "\n\t}" );
	PrintRTL( " = $WireBus" ) if( $Dir eq 'fix' );
	PrintRTL( ";\n\n" );
}

### 10:2 ������ɽ���ΥХ����� get ���� #######################################

sub GetBusWidth {
	local( $_ ) = @_;
	
	if( $_ =~ /^(\d+):(\d+)$/ ){
		return( $1, $2 );
	}elsif( $_ eq '' ){
		return( 0, 0 );
	}
	
	Warning( "unknown bit width [$_]" );
	return( -3, -1 );
}

sub GetBusWidth2 {
	my( $MSB, $LSB ) = GetBusWidth( @_ );
	return( $MSB + 1 - $LSB );
}

### Format bus width #########################################################

sub FormatBusWidth {
	local( $_ ) = @_;
	
	if( /^\d+$/ ){
		die( "FormatBusWidth()\n" );
		return "[$_:0]";
	}else{
		return "[$_]";
	}
}

### repeat output ############################################################
# syntax:
#   #repeat( [ name: ] REPEAT_NUM ) or $repeat( [ name: ] start [, stop [, step ]] )
#      ....
#   #endrep
#	
#	%d �Ȥ� %{name}d �Ǥ�����ִ�

sub RepeatOutput{
	my( $RepCntEd ) = @_;
	my( $RewindPtr ) = tell( $fpIn );
	my( $LineCnt ) = $.;
	my( $RepCnt );
	my( $VarName );
	
	my( $RepCntSt, $Step );
	
	if( $BlockNoOutput ){
		# ����ϥ֥�å���ϡ�repeat �ΰ�����̤����Υޥ���
		# �������Ƥ����ǽ��������Τǡ���������Ϥ�����
		# 1�������ԡ���
		ExpandRepeatOutput( $BLKMODE_REPEAT, 1 );
		return;
	}
	
	$RepCntEd = ExpandMacro( $RepCntEd, $EX_CPP | $EX_STR );
	
	# VarName ����
	if( $RepCntEd =~ /\s*\(\s*(\w+)\s*:([\s\S]*)/ ){
		$VarName = $1;
		$RepCntEd = "($2";
	}
	
	( $RepCntSt, $RepCntEd, $Step ) = Evaluate2( $RepCntEd );
	
	if( !defined( $RepCntEd )){
		if( $RepCntSt < 0 ){
			( $RepCntSt, $RepCntEd ) = ( -$RepCntSt - 1, -1 );
		}else{
			( $RepCntSt, $RepCntEd ) = ( 0, $RepCntSt );
		}
	}
	
	if( !defined( $Step )){
		$Step = $RepCntSt > $RepCntEd ? -1 : 1;
	}
	
	if( !IsNumber( $RepCntSt ) || !IsNumber( $RepCntEd ) || !IsNumber( $Step )){
		Error( "\$repeat() parameter isn't a number: ($RepCntSt,$RepCntEd,$Step)" );
		$RepCntEd = 0;
	}
	
	# ��ԡ��ȿ� <= 0 �����к�
	if( $RepCntSt == $RepCntEd ){
		ExpandRepeatOutput( $BLKMODE_REPEAT, 1 );
		return;
	}
	
	my $PrevRepCnt;
	$PrevRepCnt = $DefineTbl{ __REP_VAL__ }{ macro } if( defined( $DefineTbl{ __REP_VAL__ } ));
	
	for(
		$RepCnt = $RepCntSt;
		( $RepCntSt < $RepCntEd ) ? $RepCnt < $RepCntEd : $RepCnt > $RepCntEd;
		$RepCnt += $Step
	){
		AddCppMacro( '__REP_VAL__', $RepCnt, undef, 1 );
		AddCppMacro( $VarName, $RepCnt, undef, 1 ) if( defined( $VarName ));
		
		seek( $fpIn, $RewindPtr, $SEEK_SET );
		$. = $LineCnt;
		ExpandRepeatOutput( $BLKMODE_REPEAT );
	}
	
	if( defined( $PrevRepCnt )){
		AddCppMacro( '__REP_VAL__', $PrevRepCnt, undef, 1 );
	}else{
		delete( $DefineTbl{ __REP_VAL__ } );
	}
	delete( $DefineTbl{ $VarName } ) if( defined( $VarName ));
}

sub IsNumber {
	$_[ 0 ] != 0 || $_[ 0 ] =~ /^0/;
}

## foreach ##################################################################
# syntax:
#   #foreach( [ name: ] param [param...] )
#      ....
#   #endfor
#	
#	%d �Ȥ� %{name}d �Ǥ�����ִ�

sub ForeachOutput{
	local( $_ ) = @_;
	my( $RewindPtr ) = tell( $fpIn );
	my( $LineCnt ) = $.;
	my( $RepCnt );
	my( $VarName );
	
	# �ѥ�᡼���� spc or , �� split
	my( @RepParam );
	s/^\(\s*//;
	s/\s*\)$//;
	
	$_ = ExpandMacro( $_, $EX_CPP );
	
	while( $_ ){
		s/^[\s,]+//g;
		
		if( /^(".*?")([\s\S]*)/ || /^(\S+)([\s\S]*)/ ){
			push( @RepParam, $1 );
			$_ = $2;
		}
	}
	
	# VarName ����
	if( $#RepParam >= 0 && $RepParam[ 0 ] =~ /(.+):$/ ){
		$VarName = $1;
		shift( @RepParam );
	}
	
	if( $BlockNoOutput || $#RepParam < 0 ){
		# ����ϥ֥�å���ϡ�repeat �ΰ�����̤����Υޥ���
		# �������Ƥ����ǽ��������Τǡ���������Ϥ�����
		# 1�������ԡ���
		ExpandRepeatOutput( $BLKMODE_REPEAT, 1 );
		return;
	}
	
	my $PrevRepCnt;
	$PrevRepCnt = $DefineTbl{ __REP_VAL__ }{ macro } if( defined( $DefineTbl{ __REP_VAL__ } ));
	
	foreach $RepCnt ( @RepParam ){
		AddCppMacro( '__REP_VAL__', $RepCnt, undef, 1 );
		AddCppMacro( $VarName, $RepCnt, undef, 1 ) if( defined( $VarName ));
		
		seek( $fpIn, $RewindPtr, $SEEK_SET );
		$. = $LineCnt;
		ExpandRepeatOutput( $BLKMODE_REPEAT );
	}
	
	if( defined( $PrevRepCnt )){
		AddCppMacro( '__REP_VAL__', $PrevRepCnt, undef, 1 );
	}else{
		delete( $DefineTbl{ __REP_VAL__ } );
	}
	delete( $DefineTbl{ $VarName } ) if( defined( $VarName ));
}

### Exec perl ################################################################
# syntax:
#   $perl EOF
#      ....
#   EOF

sub ExecPerl {
	local $_;
	
	# print buffer �ڤ��ؤ�
	my $PrevPrintBuf = $PrintBuf;
	$PrintBuf = \$PerlBuf;
	
	# perl code ����
	ExpandRepeatOutput( $BLKMODE_PERL );
	$PrintBuf = $PrevPrintBuf;
	
	$PerlBuf =~ s/^\s*#.*$//gm;
	$PerlBuf = ExpandMacro( $PerlBuf, $EX_INTFUNC | $EX_STR | $EX_COMMENT | $EX_NOREAD );
	
	if( $Debug >= 2 ){
		print( "\n=========== perl code =============\n" );
		print( $PerlBuf );
		print( "\n===================================\n" );
	}
	$_ = ();
	$_ = eval( $PerlBuf );
	Error( $@ ) if( $@ ne '' );
	if( $Debug >= 2 ){
		print( "\n=========== output code =============\n" );
		print( $_ );
		print( "\n===================================\n" );
	}
	
	$_ .= "\n" if( $_ ne '' && !/\n$/ );
	PrintRTL( $_ );
	$ResetLinePos = $.;
}

### print all inputs #########################################################

sub PrintAllInputs {
	my( $Param, $Tab ) = @_;
	my( $Wire );
	
	$Param	=~ s/^\s*(\S+).*/$1/;
	$Tab	=~ /^(\s*)/; $Tab = $1;
	$_		= ();
	
	foreach $Wire ( @WireList ){
		if( $Wire->{ name } =~ /^$Param$/ && QueryWireType( $Wire, '' ) eq 'input' ){
			$_ .= $Tab . $Wire->{ name } . ",\n";
		}
	}
	
	s/,([^,]*)$/$1/;
	PrintRTL( $_ );
}

### requre ###################################################################

sub Require {
	if( $_[0] =~ /"(.*)"/ ){
		require $1;
	}else{
		Error( "Illegal requre file name" )
	}
}

### Tab �ǻ������Υ��ڡ���������� ###########################################

sub TabSpace {
	local $_;
	my( $Width, $TabWidth, $ForceSplit );
	( $_, $Width, $TabWidth, $ForceSplit ) = @_;
	
	my $TabNum = int(( $Width - length( $_ ) + $TabWidth - 1 ) / $TabWidth );
	$TabNum = 1 if( $ForceSplit && $TabNum == 0 );
	
	$_ . "\t" x $TabNum;
}

### CPP directive ���� #######################################################

sub AddCppMacro {
	my( $Name, $Macro, $Args, $bNoCheck ) = @_;
	
	$Macro	= '1' if( !defined( $Macro ));
	$Args	= 's' if( !defined( $Args ));
	
	if(
		( !defined( $bNoCheck ) || !$bNoCheck ) &&
		defined( $DefineTbl{ $Name } ) &&
		( $DefineTbl{ $Name }{ args } ne $Args || $DefineTbl{ $Name }{ macro } ne $Macro )
	){
		Warning( "redefined macro '$Name'" );
	}
	
	$DefineTbl{ $Name } = { 'args' => $Args, 'macro' => $Macro };
}

### if �֥�å��� eval #######################################################

sub IfBlockEval {
	local( $_ ) = @_;
	
	# defined �ִ�
	s/\bdefined\s+($CSymbol)/defined( $DefineTbl{ $1 } ) ? 1 : 0/ge;
	return Evaluate( ExpandMacro( $_, $EX_CPP | $EX_STR | $EX_NOREAD ));
}

### CPP �ޥ���Ÿ�� ###########################################################

sub ExpandMacro {
	local $_;
	my $Mode;
	
	( $_, $Mode ) = @_;
	
	my $Line;
	my $Line2;
	my $Name;
	my( $ArgList, @ArgList );
	my $ArgNum;
	my $i;
	
	$Mode = $EX_CPP | $EX_REP if( !defined( $Mode ));
	
	if( $BlockRepeat && $Mode & $EX_REP ){
		s/%(?:\{(.+?)\})?([+\-\d\.#]*[%cCdiouxXeEfgGnpsSb])/ExpandPrintfFmtSub( $2, $1 )/ge;
	}
	
	my $bReplaced = 1;
	if( $Mode & $EX_CPP ){
		while( $bReplaced ){
			$bReplaced = 0;
			$Line = '';
			
			while( /(.*?)\b($CSymbol)\b(.*)/s ){
				$Line .= $1;
				( $Name, $_ ) = ( $2, $3 );
				
				if( $Name eq '__FILE__' ){		$Line .= $DefFile;
				}elsif( $Name eq '__LINE__' ){	$Line .= $.;
				}elsif( !defined( $DefineTbl{ $Name } )){
					# �ޥ���ǤϤʤ�
					$Line .= $Name;
				}elsif( $DefineTbl{ $Name }{ args } eq 's' ){
					# ñ��ޥ���
					$Line .= $DefineTbl{ $Name }{ macro };
					$bReplaced = 1;
				}else{
					# �ؿ��ޥ���
					s/^\s+//;
					
					if( !/^\(/ ){
						# hoge( �ˤʤäƤʤ�
						Error( "invalid number of macro arg: $Name" );
						$Line .= $Name;
					}else{
						# �ޥ����������
						$_ = GetFuncArg( $fpIn, $_ );
						
						# �ޥ����������
						if( /^($OpenClose)(.*)/s ){
							( $ArgList, $_ ) = ( $1, $2 );
							$ArgList =~ s/<__COMMENT_\d+__>//g;
							$ArgList =~ s/[\t ]*[\x0D\x0A]+[\t ]*/ /g;
							$ArgList =~ s/^\(\s*//;
							$ArgList =~ s/\s*\)$//;
							
							undef( @ArgList );
							
							while( $ArgList ne '' ){
								last if( $ArgList !~ /^\s*($OpenCloseArg)\s*(,?)\s*(.*)/ );
								push( @ArgList, $1 );
								$ArgList = $3;
								
								if( $2 ne '' && $ArgList eq '' ){
									push( @ArgList, '' );
								}
							}
							
							if( $ArgList eq '' ){
								# ���������å�
								$ArgNum = $DefineTbl{ $Name }{ args };
								$ArgNum = -$ArgNum - 1 if( $ArgNum < 0 );
								
								if( !(
									$DefineTbl{ $Name }{ args } >= 0 ?
										( $ArgNum == $#ArgList + 1 ) : ( $ArgNum <= $#ArgList + 1 )
								)){
									Error( "invalid number of macro arg: $Name" );
									$Line .= $Name . '()';
								}else{
									# ��������°������ִ�
									$Line2 = $DefineTbl{ $Name }{ macro };
									$Line2 =~ s/<__ARG_(\d+)__>/$ArgList[ $1 ]/g;
									
									# ���Ѱ������ִ�
									if( $DefineTbl{ $Name }{ args } < 0 ){
										if( $#ArgList + 1 <= $ArgNum ){
											# ���� 0 �Ĥλ��ϡ�����ޤ��Ȥ�ä�
											$Line2 =~ s/,?\s*(?:##)*\s*__VA_ARGS__\s*/ /g;
										}else{
											$Line2 =~ s/(?:##\s*)?__VA_ARGS__/join( ', ', @ArgList[ $ArgNum .. $#ArgList ] )/ge;
										}
									}
									$Line .= $Line2;
									$bReplaced = 1;
								}
							}else{
								# $ArgList ���������񤷤���ʤ��ä��饨�顼
								Error( "invalid macro arg: $Name" );
								$Line .= $Name . '()';
							}
						}
					}
				}
			}
			$_ = $Line . $_;
		}
		
		# �ȡ�����Ϣ��黻�� ##
		$bReplaced |= s/\s*##\s*//g;
	}
	
	if( $Mode & $EX_INTFUNC ){
		s/\bsizeof($OpenClose)/SizeOf( $1, $Mode )/ge;
		s/\btypeof($OpenClose)/TypeOf( $1, $Mode )/ge;
		s/\$Eval($OpenClose)/Evaluate( ExpandMacro( $1 , $EX_STR | $EX_NOREAD ))/ge;
	}
	
	if( $Mode & $EX_RMSTR ){
		s/<__STRING_\d+__>/ /g;
	}elsif( $Mode & $EX_STR ){
		# ʸ����
		s/\$String($OpenClose)/Stringlize( $1 )/ge;
		
		# ʸ�����������
		s/<__STRING_(\d+)__>/$CommentPool[ $1 ]/g;
		
		# ʸ�����ƥ��Ϣ��
		1 while( s/((?<!\\)".*?)(?<!\\)"\s*"(.*?(?<!\\)")/$1$2/g );
	}
	
	# ������
	if( $Mode & $EX_RMCOMMENT ){
		s/<__COMMENT_\d+__>/ /g;
	}elsif( $Mode & $EX_COMMENT ){
		s/<__COMMENT_(\d+)__>/$CommentPool[ $1 ]/g;
	}
	
	$_;
}

sub ExpandPrintfFmtSub {
	my( $Fmt, $Name ) = @_;
	my $Num;
	
	if( !defined( $Name )){
		$Name = '__REP_VAL__';
	}
	if( !defined( $DefineTbl{ $Name } )){
		Error( "repeat var not defined '$Name'" );
		return( 'undef' );
	}
	return( sprintf( "%$Fmt", $DefineTbl{ $Name }{ macro } ));
}

### sizeof / typeof ##########################################################

sub SizeOf {
	local( $_ );
	my( $Flag );
	( $_, $Flag ) = @_;
	
	my $Wire = 0;
	my $Bits = 0;
	
	return 'x' if( $Flag & $EX_NOSIGINFO );
	
	while( s/($CSymbol)// ){
		if( !defined( $Wire = $WireList{ $1 } )){
			Error( "undefined wire '$1'" );
		}elsif( $Wire->{ width } =~ /(\d+):(\d+)/ ){
			$Bits += ( $1 - $2 + 1 );
		}else{
			++$Bits;
		}
	}
	$Bits;
}

sub TypeOf {
	local( $_ );
	my( $Flag );
	( $_, $Flag ) = @_;
	
	return '[?]' if( $Flag & $EX_NOSIGINFO );
	
	if( !/($CSymbol)/ ){
		Error( "syntax error (typeof)" );
		$_ = '';
	}elsif( !defined( $_ = $WireList{ $1 } )){
		Error( "undefined wire '$1'" );
		$_ = '';
	}else{
		$_ = $_->{ width } eq '' ? '' : "[$_->{ width }]";
	}
	$_;
}

sub Stringlize {
	local( $_ ) = @_;
	
	s/^\(\s*//;
	s/\s*\)$//;
	
	return "\"$_\"";
}

### �ե����� include #########################################################

sub Include {
	local( $_ ) = @_;
	
	$_ = ExpandMacro( $_, $EX_CPP | $EX_STR | $EX_NOREAD );
	$_ = $1 if( /"(.*?)"/ || /<(.*?)>/ );
	
	push(
		@IncludeList, {
			RewindPtr	=> tell( $fpIn ),
			LineCnt		=> $.,
			FileName	=> $DefFile
		}
	);
	
	close( $fpIn );
	
	if( !open( $fpIn, "< $_" )){
		Error( "can't open include file '$_'" );
	}else{
		$DefFile = $_;
		PrintRTL( "# 1 \"$_\"\n" );
		print( "including file '$_'...\n" ) if( $Debug >= 2 );
		ExpandRepeatOutput();
		printf( "back to file '%s'...\n", $IncludeList[ $#IncludeList ]->{ FileName } ) if( $Debug >= 2 );
	}
	
	$_ = pop( @IncludeList );
	
	$DefFile = $_->{ FileName };
	open( $fpIn, "< $DefFile" );
	
	seek( $fpIn, $_->{ RewindPtr }, $SEEK_SET );
	$. = $_->{ LineCnt };
	$ResetLinePos = $.;
}

### �Ķ��ѿ�Ÿ�� #############################################################

sub ExpandEnv {
	local( $_ ) = @_;
	
	s/(\$\{.+?\})/ExpandEnvSub( $1 )/ge;
	s/(\$\(.+?\))/ExpandEnvSub( $1 )/ge;
	
	$_;
}

sub ExpandEnvSub {
	local( $_ ) = @_;
	my( $org ) = $_;
	
	s/^\$[\(\{]//;
	s/[\}\)]$//;
	
	$ENV{ $_ } || $org;
}

### RTL��def �� ##############################################################

my %DeflizeDelPort;

sub Deflize {
	local( $_ ) = '';
	my( $FileName ) = @_;
	my $fpIn;
	my $Buf;
	
	if( !open( $fpIn, "< $FileName" )){
		Error( "can't open file \"$FileName\"" );
		return;
	}
	while( $Buf = ReadLine( $fpIn )){
		$_ .= $Buf;
	}
	close( $fpIn );
	
	s/(\bmodule\b.*?\bendmodule\b)/&DeflizeModule( $1, $FileName )/ges;
	
	# ����������
	s/\b(always\s*@\s*$OpenClose)/&DeflizeAlways( $1 )/ges;
	s/^[\t ]*\n(?:[\t ]*\n)+/\n/gm;
	
	if( !( $FileName =~ s/(.+)\.(.+)/$1.def.$2/ )){
		$FileName .= ".def";
	}
	
	open( fpOut, "> $FileName" );
	print( fpOut ExpandMacro( $_, $EX_STR | $EX_COMMENT ));
	close( fpOut );
}

### module ��ν���

sub DeflizeModule {
	local( $_ );
	my $FileName;
	( $_, $FileName ) = @_;
	
	# �⥸�塼��̾
	/module\s+($CSymbol)/;
	my $ModuleName = $1;
	
	# �⥸�塼�� IO ����
	RegisterModuleIO( $ModuleName, $FileName );
	
	# �ݡ�������Ͼä�
	my $V2KPortDef = 0;
	/\bmodule\s+$CSymbol\s*\((.*?)\);/s;
	
	if(	$1 =~ /$SigTypeDef/ ){
		$V2KPortDef = 1;
	}else{
		s/(\bmodule\s+$CSymbol)\s*\(.*?\);/$1<__PORT_DECL__>/s;
		
		# IO �Ȥ���ʳ���ʬΥ
		s/<__PORT_DECL__>(.*(?:input|output|inout)\b.*?\n)/<__PORT_DECL__>/s;
		my $IoDecl = $1;
		$IoDecl =~ s/^\s*(?:reg|wire)\b.*\n//gm;
		$IoDecl =~ s/;/,/g;
		$IoDecl =~ s/(.*),/$1/s;
		$IoDecl =~ s/^\s*(<__COMMENT_)/\t$1/gm;
		$IoDecl =~ s/^\s+//g;
		
		s/<__PORT_DECL__>/(\n$IoDecl);/;
	}
	
	# ���󥹥��󥹸ƤӽФ��� def ��
	s/^([ \t]*\b($CSymbol)\s+(#$OpenClose\s+)?($CSymbol)\s*($OpenClose)\s*;)/&DeflizeInstance( $2, $3, $4, $5, $1 )/gesm;
	
	# ����������
	s/^(<__COMMENT_)/\t$1/gm;
	
	# IO, wire ���Ԥ��Ľ���
	my @Buf = split( /\n/, $_ );
	my $Buf = '';
	
	my( $Type, $Width, $Name, $Eol, $Comment );
	foreach $_ ( @Buf ){
		if( /^\s*($SigTypeDef)\s*(\[.+?\])?\s*($CSymbol)\s*([,;]?)(.*)/ ){
			( $Type, $Width, $Name, $Eol, $Comment ) = ( $1, $2, $3, $4, $5 );
			
			if(
				# output + reg �� reg ��������
				!$V2KPortDef &&
				$Type eq 'reg' && $WireList{ $Name } &&
				( $WireList{ $Name }{ attr } & $ATTR_OUT ) ||
				
				# ��ư�����磻�����
				$Type eq 'wire' && $DeflizeDelPort{ $Name }
			){
				next;
			}
			
			# output + reg �� output �� output reg ���ѹ�
			if(
				!$V2KPortDef &&
				$Type eq 'output' && $WireList{ $Name } &&
				( $WireList{ $Name }{ attr } & $ATTR_REF )	# reg ������줿
			){
				$Type = 'output reg';
			}
			
			$_ = "\t" .
				TabSpace( $Type, $TabWidthType, $TabWidth ) .
				TabSpace( $Width || '', $TabWidthBit,  $TabWidth ) .
				"$Name$Eol$Comment";
		}
		
		$Buf .= "$_\n";
	}
	
	$Buf =~ s/\n$//;
	$Buf;
}

# instance ��ν���

sub DeflizeInstance {
	local $_;
	my( $Module, $Param, $Inst, $OrgRtl );
	( $Module, $Param, $Inst, $_, $OrgRtl ) = @_;
	
	$Inst =~ s/$Module/*/g;	#*/
	
	# ���󥹥��󥹸ƤӽФ��äݤ��ʤ��ä��餽�Τޤ��֤�
	return $OrgRtl if( !/\.$CSymbol\s*\(/ );
	
	# ����
	s/<__.*?__>/ /g;
	s/\s+/ /g;
	s/(\W) +/$1/g;
	s/ +(\W)/$1/g;
	s/^\((.*)\)$/$1/g;
	s/^\.//;
	
	my @ConnList = split( /,\./, $_ );
	
	# �����ꥹ�Ȥ��Ȥ˽���
	my $ConnListDef;
	
	foreach $_ ( @ConnList ){
		/^($CSymbol)\((.*)\)/;
		
		if( $2 eq '' ){
			$ConnListDef .= "\t\t" . TabSpace( "$1", 40, $TabWidth, 1 ) . "NC\n";
		}elsif( $1 ne $2 ){
			$ConnListDef .= "\t\t" . TabSpace( "$1", 20, $TabWidth, 1 ) . "$2\n";
		}
		
		# ��ư�����磻��κ��ͽ��
		$_ = $2;
		s/\[.*?\]//g;
		$DeflizeDelPort{ $_ } = 1 if( /^$CSymbol$/ );
	}
	
	return "\tinstance $Module " . ( $Param || '' ) . "$Inst * (\n" . $ConnListDef . "\t);";
}

sub DeflizeAlways {
	local( $_ ) = @_;
	
	return /\b(?:pos|neg)edge\b/ ? $_ : "always@( * )";
}
