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
my $ATTR_IN_CLK		= ( $enum <<= 1 );		# ���� in_clk
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
my $BLKMODE_IF		= $enum++;	# if �֥�å�
my $BLKMODE_ELSE	= $enum++;	# else �֥�å�

$enum = 1;
my $EX_CPP			= $enum;		# CPP �ޥ���Ÿ��
my $EX_STR			= $enum <<= 1;	# ʸ�����ƥ��
my $EX_RMSTR		= $enum <<= 1;	# ʸ�����ƥ����
my $EX_COMMENT		= $enum <<= 1;	# ������
my $EX_RMCOMMENT	= $enum <<= 1;	# �����Ⱥ��

$enum = 1;
my $MODMODE_NONE	= 0;
my $MODMODE_NORMAL	= $enum;
my $MODMODE_TEST	= $enum <<= 1;
my $MODMODE_INC		= $enum <<= 1;
my $MODMODE_TESTINC	= $MODMODE_TEST | $MODMODE_INC;
my $MODMODE_PROGRAM	= $enum <<= 1;

$enum = 1;
my $RL_SCPP			= $enum;		# $SCPP �����Ȥ򳰤�

$enum = 1;
my $CM_NOOUTPUT		= $enum;		# $SCPP �����Ȥ򳰤�

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
my $OpenCloseBlock;
   $OpenCloseBlock	= qr/\{[^{}]*(?:(??{$OpenCloseBlock})[^{}]*)*\}/;
my $OpenCloseType;
   $OpenCloseType	= qr/\<[^<>]*(?:(??{$OpenCloseType})[^<>]*)*\>/;
my $Debug	= 0;

my $SEEK_SET = 0;

my $FileInfo;
my $ListFile;
my $ModuleName;
my $ExpandTab;
my $BlockNoOutput	= 0;

my $ResetLinePos	= 0;
my $VppStage		= 0;
my $bPrevLineBlank	= 1;
my $CppOnly			= 0;
my @IncludeList;

# ����ơ��֥�ط�
my @WireList;
my %WireList;
my @SkelList;
my $iModuleMode;
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
		}else					 { last;
		}
		shift( @ARGV );
	}
	
	# tab ��Ĵ��
	$tab0 = $TabWidth * 2;
	
	# set up default file name
	
	my $SrcFile = $ARGV[ 0 ];
	   $SrcFile =~ /(.*?)(\.def)?(\.[^\.]+)$/;
	
	my $DstFile  = "$1$3"; $DstFile  = "$1_top$3" if( $DstFile eq $SrcFile );
	$ListFile = "$1.list";
	
	return if( !CPreprocessor( $SrcFile ));
	
	if( $CppOnly ){
		my $fp = $FileInfo->{ In };
		while( <$fp> ){
			print( $Debug ? $_ : ExpandMacro( $_, $EX_STR | $EX_COMMENT ));
		}
	}else{
		# vpp
		
		unlink( $ListFile );
		
		$ExpandTab ?
			open( $FileInfo->{ Out }, "| expand -$TabWidth > $DstFile" ) :
			open( $FileInfo->{ Out }, "> $DstFile" );
		
		$VppStage = 1;
		ScppParser();
		
		close( $FileInfo->{ Out } );
		close( $FileInfo->{ In } );
	}
	
	#unlink( $FileInfo->{ OutFile } );
}

### C �ץ�ץ��å� ########################################################

sub CPreprocessor {
	( $FileInfo->{ InFile }) = @_;
	
	$FileInfo->{ OutFile } = 
		$Debug ? "$FileInfo->{ InFile }.cpp" : "$FileInfo->{ InFile }.cpp.$$";
	
	$FileInfo->{ DispFile } = $FileInfo->{ InFile };
	
	if( -e $FileInfo->{ OutFile }){
		print( "cpp: $FileInfo->{ OutFile } is exist, cpp skipped...\n" ) if( $Debug >= 2 );
	}else{
		# cpp ��������
		if( !open( $FileInfo->{ In }, "< $FileInfo->{ InFile }" )){
			Error( "can't open file \"$FileInfo->{ InFile }\"" );
			return;
		}
		
		if( !open( $FileInfo->{ Out }, "> $FileInfo->{ OutFile }" )){
			Error( "can't open file \"$FileInfo->{ OutFile }\"" );
			close( $FileInfo->{ In } );
			return;
		}
		
		CppParser();
		
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
		
		close( $FileInfo->{ Out } );
		close( $FileInfo->{ In } );
	}
	
	$FileInfo->{ InFile } = $FileInfo->{ OutFile };
	
	if( !open( $FileInfo->{ In }, "< $FileInfo->{ InFile }" )){
		Error( "can't open file \"$FileInfo->{ InFile }\"" );
		return;
	}
	
	return $FileInfo->{ In };
}

### 1���ɤ� #################################################################

sub ReadLine {
	my ( $Mode ) = @_;
	$Mode = 0 if( !defined( $Mode ));
	
	local $_ = ReadLineSub( $FileInfo->{ In });
	
	my( $Cnt );
	my( $Line );
	my( $LineCnt ) = $.;
	my $key;
	
	while( m@(//\s*\$Scpp|//#?|/\*\s*\$Scpp|/\*|(?<!\\)")@ ){
		$Cnt = $#CommentPool + 1;
		$key = $1;
		$key =~ s/\s+//g;
		
		if(( $Mode & $RL_SCPP ) && $key eq '//$Scpp' ){
			# // $Scpp �Υ����ȳ���
			s#//\s*(\$Scpp)# $1#;
		}elsif( $key =~ m#^//# ){
			# // ����������
			push( @CommentPool, $1 ) if( !$VppStage && s#(//.*)#<__COMMENT_${Cnt}__># );
		}elsif( $key eq '"' ){
			# string ����
			if( s/((?<!\\)".*?(?<!\\)")/<__STRING_${Cnt}__>/ ){
				push( @CommentPool, $1 ) if( !$VppStage );
			}else{
				Error( 'unterminated "' );
				s/"//;
			}
		}elsif(( $Mode & $RL_SCPP ) && $key eq '/*$Scpp' && s#/\*\s*(\$Scpp.*?)\*/# $1 #s ){
			# /* $Scpp */ �����ȳ���
		}elsif( $key =~ m#/\*# && s#(/\*.*?\*/)#<__COMMENT_${Cnt}__>#s ){
			# /* ... */ ���Ȥ�ȯ�����줿�顤�ִ�
			push( @CommentPool, $1 ) if( !$VppStage );
			$ResetLinePos = $.;
		}else{
			# /* ... */ ���Ȥ�ȯ������ʤ��Τǡ�ȯ�������ޤǹ� cat
			if( !( $Line = ReadLineSub( $FileInfo->{ In }, $Mode ))){
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
			$FileInfo->{ DispFile } = ( $2 eq "-" ) ? $FileInfo->{ InFile } : $2;
		}else{
			last;
		}
	}
	return '' if( !defined( $_ ));
	$_;
}

# �ؿ��ޥ����Ѥ� ( ... ) �����
sub GetFuncArg {
	local( $_ ) = @_;
	my( $Line );
	
	while( !/^$OpenClose/ ){
		$ResetLinePos = $.;
		
		if( !( $Line = ReadLine())){
			Error( "unmatched ')'" );
			last;
		}
		$_ .= $Line;
	}
	
	$_;
}

### cpp parser ##############################################################

sub CppParser {
	my( $BlockMode, $bNoOutput ) = @_;
	$BlockMode	= 0 if( !defined( $BlockMode ));
	$bNoOutput	= 0 if( !defined( $bNoOutput ));
	local( $_ );
	
	$BlockNoOutput	<<= 1;
	$BlockNoOutput	|= $bNoOutput;
	
	my $Line;
	my $i;
	my $LineCnt = $.;
	
	while( $_ = ReadLine( $RL_SCPP )){
		if( /^\s*#\s*(?:ifdef|ifndef|if|elif|else|endif|define|undef|include)\b/ ){
			
			# \ �ǽ���äƤ���Ԥ�Ϣ��
			while( /\\$/ ){
				if( !( $Line = ReadLine())){
					last;
				}
				$_ .= $Line;
			}
			
			$ResetLinePos = $.;
			
			# \ ���
			s/[\t ]*\\[\x0D\x0A]+[\t ]*/ /g;
			s/\s+$//g;
			s/^\s*#\s*//;
			
			$_ = ExpandMacro( $_, $EX_RMCOMMENT );
			
			# $DefineTbl{ $1 }{ args }:  >=0: ����  <0: ���Ѱ���  's': ñ��ޥ���
			# $DefineTbl{ $1 }{ macro }:  �ޥ����������
			
			if( /^ifdef\b(.*)/ ){
				CppParser( $BLKMODE_IF, !IfBlockEval( "defined $1" ));
			}elsif( /^ifndef\b(.*)/ ){
				CppParser( $BLKMODE_IF,  IfBlockEval( "defined $1" ));
			}elsif( /^if\b(.*)/ ){
				CppParser( $BLKMODE_IF, !IfBlockEval( $1 ));
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
				}elsif( /^include\s+(.*)/ ){
					Include( $1 );
				}elsif( !$BlockNoOutput ){
					PrintRTL( ExpandMacro( $_, $EX_CPP ));
				}
			}
		}elsif( !$BlockNoOutput ){
			$_ = ExpandMacro( $_, $EX_CPP | $EX_RMCOMMENT );
			PrintRTL( $_ );
		}
	}
	
	if( $_ eq '' && $BlockMode != $BLKMODE_NORMAL ){
		if    ( $BlockMode == $BLKMODE_IF		){ Error( "unterminated #if",		$LineCnt );
		}elsif( $BlockMode == $BLKMODE_ELSE		){ Error( "unterminated #else",		$LineCnt );
		}
	}
	
	$BlockNoOutput	>>= 1;
}

### Scpp �ѡ��� ##############################################################

sub ScppParser {
	local( $_ );
	my( $Line, $Word );
	
	while( $_ = ReadLine()){
		( $Word, $Line ) = GetWord( ExpandMacro( $_, $EX_RMCOMMENT ));
		
		if( $Word eq 'SC_MODULE' ){
			StartModule( $Line );
		}elsif( $Word eq '$ScppPutSensitive' ){
			GetSensitive( $_ );
		}elsif( $Word eq '$ScppInstance' ){
			DefineInst( $Line );
		}elsif( $Word =~ /^\$Scpp/ ){
			Error( "unknown scpp directive \"$Word\"" );
		}else{
			PrintRTL( ExpandMacro( $_, $EX_STR | $EX_COMMENT ));
		}
	}
}

### �ޥ���饤��ѡ��� #######################################################

sub MultiLineParser0 {
	local( $_ );
	my( $Line, $Word );
	
	while( $_ = ReadLine()){
		( $Word, $Line ) = GetWord(
			ExpandMacro( $_, $EX_STR | $EX_RMCOMMENT )
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
		}elsif( $Word eq '$AllInputs'		){ PrintAllInputs( $Line, $_ );
		}else{
			if( $Word =~ /^_(?:end)?(?:module|program)$/ ){
				$_ =~ s/\b_((?:end)?(?:module|program))\b/$1/;
			}
			PrintRTL( ExpandMacro( $_, $EX_STR | $EX_COMMENT ));
		}
	}
}

### Start of the module #####################################################

sub StartModule{
	local( $_ );
	( $_, $iModuleMode ) = @_;
	
	# wire list �����
	
	@WireList	= ();
	%WireList	= ();
	
	if( !s/^\s*\(\s*($CSymbol)\s*\)// ){
		Error( "syntax error (SC_MODULE)" );
		return;
	}
	
	$ModuleName = $1;
	
	# �� module �� wire / port �ꥹ�Ȥ�get
	
	my $ModuleIO = GetModuleIO( $ModuleName, $FileInfo->{ DispFile });
	
	# input/output ʸ 1 �Ԥ��Ȥν���
	
	my( $InOut, $Type, $Name, $Attr );
	foreach $_ ( @$ModuleIO ){
		( $InOut, $Type, $Name )	= split( /\t/, $_ );
		
		$Attr = $InOut eq "sc_in_clk"	? $ATTR_DEF | $ATTR_IN_CLK	:
				$InOut eq "sc_in"		? $ATTR_DEF | $ATTR_IN		:
				$InOut eq "sc_out"		? $ATTR_DEF | $ATTR_OUT		:
				$InOut eq "sc_inout"	? $ATTR_DEF | $ATTR_INOUT	:
				$InOut eq "sc_signal"	? $ATTR_DEF | $ATTR_WIRE	: 0;
		
		RegisterWire( $Name, $Type, $Attr, $ModuleName );
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
	
	# module port �ꥹ�Ȥ����
	
	$bFirst = 1;
	PrintRTL( '//' ) if( $iModuleMode & $MODMODE_INC );
	PrintRTL(( $iModuleMode & $MODMODE_PROGRAM ? 'program' : 'module' ) . " $ModuleName" );
	
	if( $iModuleMode & $MODMODE_NORMAL ){
		
		foreach $Wire ( @WireList ){
			$Type = QueryWireType( $Wire, 'd' );
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
			
			PrintRTL( FormatSigDef( $Type, $Wire->{ type }, $Wire->{ name }, ';' ));
		}
	}
	
	# buf �ˤ���Ƥ������Ҥ�ե�å���
	
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

### ���󥷥ƥ��ӥƥ��ꥹ�ȼ��� ###############################################

sub GetSensitive {
	local( $_ ) = @_;
	my $Buf = '';
	
	if( !/^(\s*)\$Scpp\w+\s*($OpenClose)\s*(BEGIN)?/ ){
		Error( "syntax error (ScppSensitive)" );
		return;
	}
	
	my( $indent, $arg, $begin ) = ( $1, $2, $3 );
	
	$arg =~ s/^\(\s*//;
	$arg =~ s/\s*\)$//;
	foreach $_ ( split( /[\s,]+/, $arg )){
		$_ = ExpandMacro( $_, $EX_STR );
		s/^"(.*)"$/$1/;
		
		$_ = $FileInfo->{ DispFile } if( $_ eq '.' );
		
		PushFileInfo( $_ );
		$Buf .= GetSensitiveSub( $_ );
		PopFileInfo();
	}
	
	print( ">>>>>$ModuleName sensitive:\n$Buf<<<<<<<<<<\n" ) if( $Debug >= 3 );
}

sub GetSensitiveSub {
	my( $File ) = $_;
	local $_;
	
	return if( !CPreprocessor( $File ));
	
	my $SubModule;
	my $Line;
	my $Process;
	my $Arg;
	my @Arg;
	my $FuncName;
	my $Buf = '';
	
	while( $_ = ReadLine()){	# ���ޥ���Ÿ��ɬ�פ��⡤�׸�Ƥ
		
		if( /\bSC_MODULE\s*\(\s*(.+?)\s*\)/ ){
			$SubModule = $1;
			$SubModule =~ s/\s+//g;
		}elsif( /\$Scpp(Method|Thread|Cthread)\s*($OpenClose)/ ){
			( $Process, $Arg ) = ( uc( $1 ), $2 );
			$Arg =~ s/^\s*\(\s*//;
			$Arg =~ s/\s*\)\s*$//;
			@Arg = split( /\s*,\s*/, $Arg );
			
			$_ = '';
			
			# '{' ';' �ޤǼ���
			while( 1 ){
				last if( /[{;]/ );
				
				if( !( $Line = ReadLine())){
					Error( "{ or ; not found (GetSensitive)" );
					last;
				}
				$_ .= $Line;
			}
			
			s/\s+/ /g;
			s/^\s*void\s+//;
			s/\s+(\W)/$1/g;
			s/(\W)\s+/$1/g;
			
			$FuncName = '';
			
			# ���饹̾���ꡤvoid hoge<fuga>::piyo( void )
			if( /^(\S+?)::($CSymbol)/ && $1 eq $ModuleName ){
				$FuncName = $2;
			}
			
			# ���饹�����
			elsif( /^($CSymbol)\s*\(/ && $SubModule eq $ModuleName ){
				$FuncName = $1;
			}
			
			next if( !$FuncName );
			
			if( $Process eq 'CTHREAD' ){
				Error( 'invalid argument $ScppCthread()' ) if( $#Arg != 0 && $#Arg != 2 );
				
				$Buf .= "SC_CTHREAD( $FuncName, $Arg[0] );\n";
				
				if( $#Arg >= 2 ){
					$Buf .= "reset_signal_is( $Arg[1], $Arg[2] );\n";
				}
				$Buf .= "\n";
			}else{
				$Buf .= "SC_$Process( $FuncName );\nsensitive << " . join( ' << ', @Arg ) . ";\n\n";
			}
		}
	}
	
	return $Buf;
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
	
	if( $VppStage ){
		# ���԰���
		s/^([ \t]*\n)([ \t]*\n)+/$1/gm;
	}else{
		if( $ResetLinePos ){
			# �����Ϻ��򤬤狼��ʤ����ޤ��Х��äƤ뤫��
			if( $ResetLinePos == $. ){
				$_ .= sprintf( "# %d \"$FileInfo->{ DispFile }\"\n", $. + 1 );
			}else{
				$_ = sprintf( "# %d \"$FileInfo->{ DispFile }\"\n", $. ) . $_;
			}
			$ResetLinePos = 0;
		}
	}
	
	if( !( $VppStage && $bPrevLineBlank && /^\s*$/ )){
		print( { $FileInfo->{ Out }} $_ );
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
		
		$InOut,
		$Type,
		$BitWidthWire,
	);
	
	@SkelList = ();
	
	my $LineNo = $.;
	
	# ��������
	$_ = ExpandMacro( GetFuncArg( $_ ));
	/($OpenClose)/;
	$_ = $1;
	
	# ���� split
	s/^\s*\(\s*//;
	s/\s*\)\s*$//;
	my @Arg = split( /\s*[,;]\s*/, $_ );
	
	if( $#Arg < 2 ){
		Error( 'invalid argument ($ScppInstance)' );
		return;
	}
	
	print( "DefineInst:" . join( ", ", @Arg ) . "\n" ) if( $Debug >= 3 );
	
	# get module name, module inst name, module file
	my $ModuleName = shift( @Arg );
	my $ModuleInst = shift( @Arg );
	my $ModuleFile = ExpandMacro( shift( @Arg ), $EX_STR );
	
	$ModuleFile =~ s/^"(.*)"$/$1/;
	$ModuleFile = $FileInfo->{ DispFile } if( $ModuleFile eq "." );
	
	# read port->wire tmpl list
	ReadSkelList( \@Arg );
	
	# get sub module's port list
	my $ModuleIO = GetModuleIO( $ModuleName, $ModuleFile );
	
	# input/output ʸ 1 �Ԥ��Ȥν���
	
	foreach $_ ( @$ModuleIO ){
		
		( $InOut, $Type, $Port ) = split( /\t/, $_ );
		next if( $InOut !~ /^sc_(?:in|in_clk|out|inout)$/ );
		
		( $Wire, $Attr ) = ConvPort2Wire( $Port, $Type, $InOut );
		
		if( !( $Attr & $ATTR_NC )){
			next if( $Attr & $ATTR_IGNORE );
			
			# hoge(\d) --> hoge[$1] �к�
			
			$WireBus = $Wire;
			if( $WireBus  =~ /(.*)\[(\d+(?::\d+)?)\]$/ ){
				# ���׽���
				
				$WireBus		= $1;
				$BitWidthWire	= $2;
				$BitWidthWire	= $BitWidthWire =~ /^\d+$/ ? "$BitWidthWire:$BitWidthWire" : $BitWidthWire;
				
				# instance �� tmpl �����
				#  hoge  hoge[1] �ʤɤΤ褦�� wire ¦�� bit ���꤬
				# �Ĥ����Ȥ� wire �μºݤΥ��������狼��ʤ�����
				# ATTR_WEAK_W °����Ĥ���
				$Attr |= $ATTR_WEAK_W;
			}else{
				$BitWidthWire	= $Type;
				
				# BusSize �� [BIT_DMEMADR-1:0] �ʤɤΤ褦�������ξ��
				# ���ΤȤ��� $ATTR_WEAK_W °����Ĥ���
				# ���׽���
				if( $Type ne '' && $Type !~ /^\d+:\d+$/ ){
					$Attr |= $ATTR_WEAK_W;
				}
			}
			
			# wire list ����Ͽ
			
			if( $Wire !~ /^\d/ ){
				$Attr |= ( $InOut eq "sc_in" )		? $ATTR_REF		:
						 ( $InOut eq "sc_in_clk" )	? $ATTR_FIX		:
						 ( $InOut eq "sc_out" )		? $ATTR_FIX		:
												 	  $ATTR_BYDIR	;
				
				RegisterWire(
					$WireBus,
					$BitWidthWire,
					$Attr,
					$ModuleName
				);
			}elsif( $Wire =~ /^\d+$/ ){
				# �������������ꤵ�줿��硤bit��ɽ����Ĥ���
				# ���׽���
				$Wire = sprintf( "%d'd$Wire", GetBusWidth2( $Type ));
			}
		}
		
		print $ModuleInst . "->$Port( $Wire )\n";
	}
	
	# SkelList ̤���ѷٹ�
	
	WarnUnusedSkelList( $ModuleInst, $LineNo );
}

### search module & get IO definition ########################################

sub GetModuleIO{
	local $_;
	my( $ModuleName, $ModuleFile, $ModuleFileDisp ) = @_;
	$ModuleFileDisp = $ModuleFile if( !defined( $ModuleFileDisp ));
	
	printf( "GetModuleIO: $ModuleName, $ModuleFile, $ModuleFileDisp\n" ) if( $Debug >= 2 );
	
	PushFileInfo( $ModuleFile );
	my $fp = CPreprocessor( $ModuleFile );
	if( !$fp ){
		PopFileInfo(); return;
	}
	
	# module ����Ƭ��õ��
	my $bFound = 0;
	my $Buf = '';
	
	while( $_ = ReadLine()){
		if( !$bFound ){
			# module ��ޤ����Ĥ��Ƥ��ʤ�
			if( /\bSC_MODULE\s*\(\s*$ModuleName\s*\)\s*(.*)/ ){
				$bFound = 1;
				$Buf = $1;
			}
		}else{
			# module ������
			$Buf .= ExpandMacro( $_, $EX_RMSTR | $EX_RMCOMMENT );
			if( $Buf =~ /^\s*($OpenCloseBlock)/ ){
				$Buf = $1;
				$bFound = 2;
				last;
			}
		}
	}
	
	PopFileInfo();
	
	if( $bFound == 0 ){
		Error( "can't find SC_MODULE \"$ModuleName\@$ModuleFile\"" );
		return( "" );
	}
	
	if( $bFound == 1 ){
		Error( "can't find end of SC_MODULE \"$ModuleName\@$ModuleFile\"" );
		return( "" );
	}
	
	$_ = $Buf;
	
	s/\n+/ /g;
	s/([\{\};])/\n/g;
	#printf( "GetModuleIO: Buf >>>>>>>>\n$_\n<<<<<<<<<<<\n" ) if( $Debug >= 3 );
	
	my $io;
	my $Type;
	my $Name;
	my @name;
	my $Port = [];
	
	foreach $_ ( split( /\n+/, $_ )){
		next if( !/^\s*(sc_(?:in|out|inout|in_clk|signal))\b\s*(.*)/ );
		
		# in / out / signal ��Ƚ��
		( $io, $_ ) = ( $1, $2 );
		
		# ������
		if( /\s*($OpenCloseType)\s*(.*)/ ){
			( $Type, $_ ) = ( $1, $2 );
			$Type =~ s/\s+//g;
		}else{
			$Type = '';
		}
		
		# �ѿ�̾����
		foreach $Name ( split( /,/, $_ )){
			$Name =~ s/\s+//g;
			push( @$Port, "$io	$Type	$Name" );
		}
	}
	
	print "GetModuleIO: >>>>>>>>\n" . join( "\n", @$Port ) . "\n<<<<<<<<<<<\n" if( $Debug >= 3 );
	
	return $Port;
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
			print( "...included at $_->{ DispName }($_->{ LineCnt }):\n" );
		}
	}
	
	printf( "$FileInfo->{ DispFile }(%d): $_\n", $LineNo || $. );
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

### skip to semi colon #######################################################

sub SkipToSemiColon{
	
	local( $_ ) = @_;
	
	do{
		goto ExitLoop if( s/.*?;//g );
	}while( $_ = ReadLine());
	
  ExitLoop:
	return( $_ );
}

### read port/wire tmpl list #################################################

sub ReadSkelList{
	
	local $_;
	my( $List ) = @_;
	my(
		$Port,
		$Wire,
		$Attr,
		$AttrLetter
	);
	
	foreach $_ ( @$List ){
		
		if( /^$CSymbol\s*->\s*($CSymbol)\s*\(\s*($CSymbol)\s*\)/ ){
			# hoge->fuga( piyo )
			( $Port, $Wire, $AttrLetter ) = ( $1, $2, '' );
		}elsif( /^(\W)(.*?)\1(.*?)\1(.*)$/ ){
			# /hoge/fuga/opt
			( $Port, $Wire, $AttrLetter ) = ( $2, $3, $4 );
		}elsif( /^$CSymbol$/ ){
			( $Port, $Wire, $AttrLetter ) = ( $_, $_, '' );
		}else{
			Error( "syntax error (\$ScppInstance: \"$_\")" );
			next;
		}
		
		if( $Wire =~ /^[mbu]?(?:np|nc|w|i|o|io|u|\*d)$/ ){
			$AttrLetter = $Wire;
			$Wire = "";
		}
		
		# attr
		
		$Attr = 0;
		
		$Attr |= $ATTR_MD			if( $AttrLetter =~ /m/ );
		$Attr |= $ATTR_DC_WEAK_W	if( $AttrLetter =~ /b/ );
		$Attr |= $ATTR_USED			if( $AttrLetter =~ /u/ );
		$Attr |=
			( $AttrLetter =~ /np$/ ) ? $ATTR_DEF	:
			( $AttrLetter =~ /nc$/ ) ? $ATTR_NC		:
			( $AttrLetter =~ /w$/  ) ? $ATTR_WIRE	:
			( $AttrLetter =~ /i$/  ) ? $ATTR_IN		:
			( $AttrLetter =~ /o$/  ) ? $ATTR_OUT	:
			( $AttrLetter =~ /io$/ ) ? $ATTR_INOUT	:
			( $AttrLetter =~ /\*d$/ ) ? $ATTR_IGNORE	:
								0;
		
		push( @SkelList, {
			port => $Port,
			wire => $Wire,
			attr => $Attr,
		} );
		
		print( "skel: '$_' /$Port/$Wire/$Attr\n" ) if( $Debug >= 3 );
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
	
	my( $Port, $Type, $InOut ) = @_;
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
		# Hit ����
		if( $Port =~ /^$Skel->{ port }$/ ){
			# port tmpl ���Ѥ��줿
			$Skel->{ attr } |= $ATTR_USED;
			
			$SkelPort = $Skel->{ port };
			$SkelWire = $Skel->{ wire };
			$Attr	  = $Skel->{ attr };
			
			# NC �ʤ�ꥹ�Ȥ���ʤ� ���׽���
			
			if( $Attr & $ATTR_NC ){
				if( $InOut eq 'sc_in' ){
					return( "0", $Attr );
				}
				return( "", $Attr );
			}
			last;
		}
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
	
	my( $Name, $Type, $Attr, $ModuleName ) = @_;
	my( $Wire );
	
	if( defined( $Wire = $WireList{ $Name } )){
		# ���Ǥ���Ͽ�Ѥ�
		
		# ATTR_WEAK_W �������� BitWidth �򹹿�����
		if(
			!( $Attr			& $ATTR_WEAK_W ) &&
			( $Wire->{ attr }	& $ATTR_WEAK_W )
		){
			# List �� Weak �ǡ��������Τ� Hard �ʤΤ�����
			$Wire->{ type } = $Type;
			
			# list �� ATTR_WEAK_W °����ä�
			$Wire->{ attr } &= ~$ATTR_WEAK_W;
			
		}elsif(
			( $Attr				& $ATTR_WEAK_W ) &&
			( $Wire->{ attr }	& $ATTR_WEAK_W )
		){
			# List���������� �Ȥ�� Weak �ʤΤǡ�������
			
			$Wire->{ type } = $Type = "<UNKNOWN>";
			
		}elsif(
			!( $Attr			& $ATTR_WEAK_W ) &&
			!( $Wire->{ attr }	& $ATTR_WEAK_W ) &&
			$Wire->{ type } =~ /^\d+:\d+$/ && $Type =~ /^\d+:\d+$/
		){
			# ξ�� Hard �ʤΤǡ�����������äƤ���� size mismatch �ٹ�
			
			if( $Wire->{ type } ne $Type ){
				Warning( "unmatch port type ( $ModuleName.$Name $Type != $Wire->{ type } )" );
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
			Warning( "multiple driver ($Name)" );
		}
		
		$Wire->{ attr } |= ( $Attr & ~$ATTR_WEAK_W );
		
	}else{
		# ������Ͽ
		
		push( @WireList, $Wire = {
			name	=> $Name,
			type	=> $Type,
			attr	=> $Attr
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
			"\t$Wire->{ type }\t$Wire->{ name }\n"
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
		
		printf( "Wire info : Unresolved:%3d / Added:%3d ( $ModuleName\@$FileInfo->{ DispFile } )\n",
			$WireCntUnresolved, $WireCntAdded );
		
		my $fp;
		if( !open( $fp, ">> $ListFile" )){
			Error( "can't open file \"$ListFile\"" );
			return;
		}
		
		print( $fp "*** $ModuleName wire list ***\n" );
		print( $fp @WireListBuf );
		close( $fp );
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
		if( $Wire->{ name } =~ /\$n/ && $Wire->{ type } ne "" ){
			
			# Ÿ�����٤��Х�
			
			$Name		= $Wire->{ name };
			$Attr		= $Wire->{ attr };
			$BitWidth	= $Wire->{ type };
			
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
	return Evaluate( ExpandMacro( $_, $EX_CPP | $EX_STR ));
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
	
	$Mode = $EX_CPP if( !defined( $Mode ));
	
	my $bReplaced = 1;
	if( $Mode & $EX_CPP ){
		while( $bReplaced ){
			$bReplaced = 0;
			$Line = '';
			
			while( /(.*?)\b($CSymbol)\b(.*)/s ){
				$Line .= $1;
				( $Name, $_ ) = ( $2, $3 );
				
				if( $Name eq '__FILE__' ){		$Line .= $FileInfo->{ DispFile };
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
						$_ = GetFuncArg( $_ );
						
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

### sizeof / typeof ##########################################################

sub Stringlize {
	local( $_ ) = @_;
	
	s/^\(\s*//;
	s/\s*\)$//;
	
	return "\"$_\"";
}

### �ե����� include #########################################################

sub PushFileInfo {
	local( $_ ) = @_;
	
	print( "pushing FileInfo $FileInfo->{ InFile } -> $_\n" ) if( $Debug >= 2 );
	
	$FileInfo->{ RewindPtr }	= tell( $FileInfo->{ In } );
	$FileInfo->{ LineCnt }		= $.;
	
	my $PrevFileInfo = $FileInfo;
	
	push( @IncludeList, $FileInfo );
	close( $FileInfo->{ In } );
	
	$FileInfo = {
		InFile		=> $_,
		DispFile	=> $_,
		OutFile		=> $PrevFileInfo->{ OutFile },
		Out			=> $PrevFileInfo->{ Out },
	};
}

sub PopFileInfo {
	close( $FileInfo->{ In });
	
	print( "poping FileInfo $FileInfo->{ InFile } -> " ) if( $Debug >= 2 );
	$FileInfo = pop( @IncludeList );
	print( "$FileInfo->{ InFile }\n" ) if( $Debug >= 2 );
	
	open( $FileInfo->{ In }, "< $FileInfo->{ InFile }" );
	seek( $FileInfo->{ In }, $FileInfo->{ RewindPtr }, $SEEK_SET );
	
	$. = $FileInfo->{ LineCnt };
	$ResetLinePos = $.;
}

sub Include {
	local( $_ ) = @_;
	
	$_ = ExpandMacro( $_, $EX_CPP | $EX_STR );
	
	if( /<.+>/ ){
		PrintRTL( "\n" );
		return;
	}
	
	$_ = $1 if( /"(.*?)"/ );
	
	PushFileInfo( $_ );
	
	if( !open( $FileInfo->{ In }, "< $_" )){
		Error( "can't open include file '$_'" );
	}else{
		$FileInfo->{ InFile } = $_;
		PrintRTL( "# 1 \"$_\"\n" );
		print( "including file '$_'...\n" ) if( $Debug >= 2 );
		CppParser();
		printf( "back to file '%s'...\n", $IncludeList[ $#IncludeList ]->{ InFile } ) if( $Debug >= 2 );
	}
	
	PopFileInfo();
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
