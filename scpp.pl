#!/usr/bin/perl -w
##############################################################################
#
#		scpp -- SystemC preprocessor
#		Copyright(C) by DDS
#
##############################################################################
#
# ��ToDo:
# Port �� array �б�
# sc_in_clk �� <bool> ��Ʊ�������ˤ���
# port NC, ��������Ƥ����
# ScppInstance �ν񼰤Ϥ���Ǥ����Τ�?
# ScppAutoMember �� module �ݥ��󥿤�ޤ��٤���?
# ���󥹥��󥹤Υ�ԡ��Ȥ�Ƥ���뢪for �ǹԤ��뵤������
# include �ե������ env expand
# ScppInitializer �� , ����ʤ�����
# sensitivity ��ؿ����Ǥ�դξ��˽�
# Ÿ���������ʤ��ޥ������
# perl Ÿ��
# SC_MODULE �ηѾ������Ȥ��Ȥ�ư���ʤ���������

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
my $ATTR_DEF		= ( $enum <<= 1 );		# �ݡ��ȡ���������Ѥ�
my $ATTR_USED		= ( $enum <<= 1 );		# ���� template �����Ѥ��줿
my $ATTR_IGNORE		= ( $enum <<= 1 );		# `ifdef �ڤ���������̵���ݡ��Ȥ�̵�뤹����
my $ATTR_NC			= ( $enum <<= 1 );		# ���� 0 ���ꡤ���� open

$enum = 0;
my $BLKMODE_NORMAL	= $enum;	# �֥�å���
my $BLKMODE_IF		= $enum++;	# if �֥�å�
my $BLKMODE_ELSE	= $enum++;	# else �֥�å�

$enum = 1;
my $EX_CPP			= $enum;		# CPP �ޥ���Ÿ��
my $EX_STR			= $enum <<= 1;	# ʸ�����ƥ��
my $EX_RMSTR		= $enum <<= 1;	# ʸ�����ƥ����
my $EX_COMMENT		= $enum <<= 1;	# ������
my $EX_RMCOMMENT	= $enum <<= 1;	# �����Ⱥ��
my $EX_SP			= $enum <<= 1;	# ���ڡ���������

my $CSymbol			= qr/\b[_a-zA-Z]\w*\b/;
my $DefSkelPort		= '(.*)';
my $DefSkelWire		= '$1';

my $OpenClose;
   $OpenClose		= qr/\([^()]*(?:(??{$OpenClose})[^()]*)*\)/;
my $OpenCloseArg	= qr/[^(),]*(?:(??{$OpenClose})[^(),]*)*/;
my $OpenCloseBlock;
   $OpenCloseBlock	= qr/\{[^{}]*(?:(??{$OpenCloseBlock})[^{}]*)*\}/;
my $OpenCloseType;
   $OpenCloseType	= qr/\<[^<>]*(?:(??{$OpenCloseType})[^<>]*)*\>/;

use constant {
	SEEK_SET	=> 0
};

my $ErrorCnt = 0;

# option
my $CppOnly	= 0;
my $Debug	= 0;
my @IncludeList;
my @IncludePath;

# ����ơ��֥�ط�
my $CppInfo;
my $FileInfo;
my $ModuleInfo;
my @TmpFileList;

main();
exit( $ErrorCnt != 0 );

### main procedure ###########################################################

sub main{
	local( $_ );
	
	if( $#ARGV < 0 ){
		print( "usage: scpp.pl [-vE] [-I<path>] [-D<def>[=<val>]] [-o <dst_file>] <src_file>\n" );
		return;
	}
	
	my $DstFile;
	
	while( 1 ){
		$_ = $ARGV[ 0 ];
		
		if    ( m#^-I(.+)\/?$#	){ push( @IncludePath, $1 );
		}elsif( $_ eq '-I' 		){
			shift( @ARGV );
			$ARGV[ 0 ] =~ m#^-I(.+)\/?$#;
			push( @IncludePath, $1 );
			
		}elsif( /^-D(.+?)=(.+)/	){ AddCppMacro( $1, $2 );
		}elsif( /^-D(.+)/		){ AddCppMacro( $1 );
		}elsif( $_ eq '-o'		){
			shift( @ARGV );
			$DstFile = $ARGV[ 0 ];
		}elsif( /^-/			){
			while( s/v// ){ ++$Debug; }
			$CppOnly = 1 if( /E/ );
		}else					 { last;
		}
		shift( @ARGV );
	}
	
	# set up default file name
	
	my $SrcFile = $ARGV[ 0 ];
	$DstFile = $SrcFile if( !defined( $DstFile ));
	$SrcFile =~ /(.*?)(\.def)?(\.[^\.]+)$/;
	my $ListFile = "$1.list";
	
	my $DstFileTmp = ( $DstFile eq $SrcFile ) ?
		"$SrcFile.$$.scpp.tmp" : $DstFile;
	
	return if( !CPreprocessor( $SrcFile ));
	
	if( $CppOnly ){
		my $fp = $FileInfo->{ In };
		while( <$fp> ){
			print( $Debug ? $_ : ExpandMacro( $_, $EX_STR | $EX_COMMENT ));
		}
	}else{
		close( $FileInfo->{ In });
		undef( $FileInfo->{ In });
		undef( $FileInfo->{ InFile });
		
		# vpp
		unlink( $ListFile );
		
		ScppParser();
		ScppOutput( $SrcFile, $DstFileTmp ) if( !$ErrorCnt );
		OutputWireList( $ListFile );
		
		system( << "-----" ) if( !$ErrorCnt && $DstFile eq $SrcFile );
			if diff -q '$SrcFile' '$DstFileTmp' > /dev/null 2>&1; then
				rm '$DstFileTmp'
			else
				mv -f '$SrcFile' '$SrcFile.bak'
				mv -f '$DstFileTmp' '$SrcFile'
			fi
-----
	}
	
	unlink( @TmpFileList );
}

### C �ץ�ץ��å� ########################################################

sub CPreprocessor {
	$FileInfo = {
		LineCnt => 0
	};
	
	( $FileInfo->{ InFile }) = @_;
	
	$CppInfo = {
		InFile			=> $FileInfo->{ InFile },
		OutFile			=> "$FileInfo->{ InFile }.$$.cpp.tmp",
		BlockNoOutput	=> 0,
		ResetLinePos	=> 0,
	};
	push( @TmpFileList, $CppInfo->{ OutFile });
	
	$FileInfo->{ DispFile } = $FileInfo->{ InFile };
	
	if( -e $CppInfo->{ OutFile }){
		print( "cpp: $CppInfo->{ OutFile } is exist, cpp skipped...\n" ) if( $Debug >= 2 );
	}else{
		# cpp ��������
		if( !open( $FileInfo->{ In }, "< $FileInfo->{ InFile }" )){
			Error( "can't open file \"$FileInfo->{ InFile }\"", 0 );
			undef $FileInfo->{ In };
			return;
		}
		
		if( !open( $CppInfo->{ Out }, "> $CppInfo->{ OutFile }" )){
			Error( "can't open file \"$CppInfo->{ OutFile }\"", 0 );
			close( $FileInfo->{ In } );
			undef $FileInfo->{ In };
			undef $FileInfo->{ Out };
			return;
		}
		
		CppParser();
		
		if( $Debug >= 2 ){
			print( "=== macro ===\n" );
			foreach $_ ( sort keys %{ $CppInfo->{ DefineTbl }} ){
				printf( "$_%s\t%s\n",
					$CppInfo->{ DefineTbl }{ $_ }{ args } eq 's' ? '' : '()',
					$CppInfo->{ DefineTbl }{ $_ }{ macro }
				);
			}
			print( "=== comment =\n" );
			print( join( "\n", @{ $CppInfo->{ CommentPool }} ));
			print( "\n=============\n" );
		}
		
		close( $CppInfo->{ Out } );
		close( $FileInfo->{ In } );
	}
	
	$FileInfo->{ InFile } = $CppInfo->{ OutFile };
	
	if( !open( $FileInfo->{ In }, "< $FileInfo->{ InFile }" )){
		Error( "can't open file \"$FileInfo->{ InFile }\"", 0 );
		return;
	}
	
	return $FileInfo->{ In };
}

### 1���ɤ� #################################################################

sub ReadLine {
	local $_ = ReadLineSub( $FileInfo->{ In });
	
	my( $Cnt );
	my( $Line );
	my( $LineCnt ) = $.;
	my $key;
	
	while( m@(//\s*\$Scpp|//#?|/\*\s*\$Scpp|/\*|(?<!\\)")@ ){
		$Cnt = $#{ $CppInfo->{ CommentPool }} + 1;
		$key = $1;
		$key =~ s/\s+//g;
		
		if( $key eq '//$Scpp' ){
			# // $Scpp �Υ����ȳ���
			s#//\s*(\$Scpp)#$1#;
		}elsif( $key =~ m#^//# ){
			# // ����������
			push( @{ $CppInfo->{ CommentPool }}, $1 ) if( s#(//.*)#<__COMMENT_${Cnt}__># );
		}elsif( $key eq '"' ){
			# string ����
			if( s/((?<!\\)".*?(?<!\\)")/<__STRING_${Cnt}__>/ ){
				push( @{ $CppInfo->{ CommentPool }}, $1 );
			}else{
				Error( 'unterminated "' );
				s/"//;
			}
		}elsif( $key eq '/*$Scpp' && s#/\*\s*(\$Scpp.*?)\*/#$1#s ){
			# /* $Scpp */ �����ȳ���
		}elsif( $key =~ m#/\*# && s#(/\*.*?\*/)#<__COMMENT_${Cnt}__>#s ){
			# /* ... */ ���Ȥ�ȯ�����줿�顤�ִ�
			push( @{ $CppInfo->{ CommentPool }}, $1 );
			$CppInfo->{ ResetLinePos } = $.;
		}else{
			# /* ... */ ���Ȥ�ȯ������ʤ��Τǡ�ȯ�������ޤǹ� cat
			if( !( $Line = ReadLineSub( $FileInfo->{ In } ))){
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
		if( /^#\s*(\d+)\s+"(.*)"/ ){
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
		$CppInfo->{ ResetLinePos } = $.;
		
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
	
	$CppInfo->{ BlockNoOutput }	<<= 1;
	$CppInfo->{ BlockNoOutput }	|= $bNoOutput;
	
	my $Line;
	my $i;
	my $LineCnt = $.;
	my $arg;
	my $tmp;
	
	while( $_ = ReadLine()){
		if( /^\s*#\s*(?:ifdef|ifndef|if|elif|else|endif|define|undef|include)\b/ ){
			
			# \ �ǽ���äƤ���Ԥ�Ϣ��
			while( /\\$/ ){
				if( !( $Line = ReadLine())){
					last;
				}
				$_ .= $Line;
			}
			
			$CppInfo->{ ResetLinePos } = $.;
			
			# \ ���
			s/[\t ]*\\[\x0D\x0A]+[\t ]*/ /g;
			s/\s+$//g;
			s/^\s*#\s*//;
			
			$_ = ExpandMacro( $_, $EX_RMCOMMENT );
			
			# $CppInfo->{ DefineTbl }{ $1 }{ args }:  >=0: ����  <0: ���Ѱ���  's': ñ��ޥ���
			# $CppInfo->{ DefineTbl }{ $1 }{ macro }:  �ޥ����������
			
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
					$CppInfo->{ BlockNoOutput } &= ~1;
					$CppInfo->{ BlockNoOutput } |= 1 if( $bNoOutput );
				}else{
					# �⤦���Ϥ���
					$CppInfo->{ BlockNoOutput } |= 1;
				}
			}elsif( /^else\b/ ){
				# else
				if( $BlockMode != $BLKMODE_IF ){
					Error( "unexpected #else" );
				}elsif( $bNoOutput ){
					# �ޤ����Ϥ��Ƥ��ʤ�
					$bNoOutput = 0;
					$CppInfo->{ BlockNoOutput } &= ~1;
				}else{
					# �⤦���Ϥ���
					$CppInfo->{ BlockNoOutput } |= 1;
				}
			}elsif( /^endif\b/ ){
				# endif
				if( $BlockMode != $BLKMODE_IF ){
					Error( "unexpected #endif" );
				}else{
					last;
				}
			}elsif( !$CppInfo->{ BlockNoOutput } ){
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
					delete( $CppInfo->{ DefineTbl }{ $1 } );
				}elsif( /^include\s+(.*)/ ){
					Include( $1 );
				}else{
					# �����ˤ���ʤ��Ȼפ�...
					Error( "internal error: cpp: \"$1\"\n" );
				}
			}
		}elsif( !$CppInfo->{ BlockNoOutput } ){
			$_ = ExpandMacro( $_, $EX_CPP | $EX_RMCOMMENT );
			PrintRTL( $_ );
			
			# scpp directive ���ֲ���
			$Line = $_ = ExpandMacro( $_, $EX_SP );
			
			# SrcFile �������ʳ��ϲ����򥹥��å�
			if( $CppInfo->{ InFile } eq $FileInfo->{ InFile }){
				if( /^(SC_MODULE)\(($CSymbol)\)/ ){
					push( @{ $CppInfo->{ ScppInfo }}, {
						Keyword		=> $1,
						ModuleName	=> $2,
						Line		=> $Line,
						LineCnt		=> $.
					});
					
					$CppInfo->{ ModuleName } = $2;
					
				}elsif( !/^\$Scpp(?:Method|Thread|Cthread)/ && /^(\$Scpp\w+)($OpenClose)?/ ){
					( $tmp, $_ ) = ( $1, $2 );
					
					# arg ʬ��
					$arg = undef;
					if( $_ ){
						s/^\(//;
						s/\)$//;
						@$arg = split( /,/, $_ );
					}
					
					push( @{ $CppInfo->{ ScppInfo }}, {
						Keyword		=> $tmp,
						Arg			=> $arg,
						ModuleName	=> $CppInfo->{ ModuleName },
						Line		=> $Line,
						LineCnt		=> $.,
					});
					
					print "ScppInfo: $tmp\n" if( $Debug >= 3 );
				}
			}
		}
	}
	
	if( $_ eq '' && $BlockMode != $BLKMODE_NORMAL ){
		if( $BlockMode == $BLKMODE_IF ){
			Error( "unterminated #if", $LineCnt );
		}
	}
	
	$CppInfo->{ BlockNoOutput }	>>= 1;
}

### Evaluate #################################################################

sub Evaluate {
	local( $_ ) = @_;
	
	s/\$Eval\b//g;
	$_ = eval( $_ );
	Error( $@ ) if( $@ ne '' );
	return( $_ );
}

### output normal line #######################################################

sub PrintRTL{
	local( $_ ) = @_;
	
	if( $CppInfo->{ ResetLinePos } ){
		# �����Ϻ��򤬤狼��ʤ����ޤ��Х��äƤ뤫��
		if( $CppInfo->{ ResetLinePos } == $. ){
			$_ .= sprintf( "# %d \"$FileInfo->{ DispFile }\"\n", $. + 1 );
		}else{
			$_ = sprintf( "# %d \"$FileInfo->{ DispFile }\"\n", $. ) . $_;
		}
		$CppInfo->{ ResetLinePos } = 0;
	}
	
	print( { $CppInfo->{ Out }} $_ );
}

### CPP directive ���� #######################################################

sub AddCppMacro {
	my( $Name, $Macro, $Args, $bNoCheck ) = @_;
	
	$Macro	= '1' if( !defined( $Macro ));
	$Args	= 's' if( !defined( $Args ));
	
	if(
		( !defined( $bNoCheck ) || !$bNoCheck ) &&
		defined( $CppInfo->{ DefineTbl }{ $Name } ) &&
		( $CppInfo->{ DefineTbl }{ $Name }{ args } ne $Args || $CppInfo->{ DefineTbl }{ $Name }{ macro } ne $Macro )
	){
		Warning( "redefined macro '$Name'" );
	}
	
	$CppInfo->{ DefineTbl }{ $Name } = { 'args' => $Args, 'macro' => $Macro };
}

### if �֥�å��� eval #######################################################

sub IfBlockEval {
	local( $_ ) = @_;
	
	# defined �ִ�
	s/\bdefined\s+($CSymbol)/defined( $CppInfo->{ DefineTbl }{ $1 } ) ? 1 : 0/ge;
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
				}elsif( !defined( $CppInfo->{ DefineTbl }{ $Name } )){
					# �ޥ���ǤϤʤ�
					$Line .= $Name;
				}elsif( $CppInfo->{ DefineTbl }{ $Name }{ args } eq 's' ){
					# ñ��ޥ���
					$Line .= $CppInfo->{ DefineTbl }{ $Name }{ macro };
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
								$ArgNum = $CppInfo->{ DefineTbl }{ $Name }{ args };
								$ArgNum = -$ArgNum - 1 if( $ArgNum < 0 );
								
								if( !(
									$CppInfo->{ DefineTbl }{ $Name }{ args } >= 0 ?
										( $ArgNum == $#ArgList + 1 ) : ( $ArgNum <= $#ArgList + 1 )
								)){
									Error( "invalid number of macro arg: $Name" );
									$Line .= $Name . '()';
								}else{
									# ��������°������ִ�
									$Line2 = $CppInfo->{ DefineTbl }{ $Name }{ macro };
									$Line2 =~ s/<__ARG_(\d+)__>/$ArgList[ $1 ]/g;
									
									# ���Ѱ������ִ�
									if( $CppInfo->{ DefineTbl }{ $Name }{ args } < 0 ){
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
	
	# ʸ������
	if( $Mode & $EX_RMSTR ){
		s/<__STRING_\d+__>/ /g;
	}
	
	# �����Ⱥ��
	if( $Mode & $EX_RMCOMMENT ){
		s/<__COMMENT_\d+__>/ /g;
	}
	
	if( $Mode & $EX_SP ){
		# space ��Ŭ��
		
		s/^\s+//; s/\s+$//;
		s/(\w)\s+(\w)/$1 $2/g;
		s/\s*(\W)\s*/$1/g;
	}
	
	# ʸ����
	if( $Mode & $EX_STR ){
		# ʸ����
		s/\$String($OpenClose)/Stringlize( $1 )/ge;
		
		# ʸ�����������
		s/<__STRING_(\d+)__>/$CppInfo->{ CommentPool }[ $1 ]/g;
		
		# ʸ�����ƥ��Ϣ��
		1 while( s/((?<!\\)".*?)(?<!\\)"\s*"(.*?(?<!\\)")/$1$2/g );
	}
	
	# ������
	if( $Mode & $EX_COMMENT ){
		s/<__COMMENT_(\d+)__>/$CppInfo->{ CommentPool }[ $1 ]/g;
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

sub SearchIncludeFile {
	my( $File ) = @_;
	local $_;
	
	# �ѥ��� / ���ޤޤ�Ƥ����鲿�⤷�ʤ�
	return $File if( $File =~ m#/# || -e $File );
	
	foreach $_ ( @IncludePath ){
		s#/$##;
		return "$_/$File" if( -e "$_/$File" );
	}
	
	return $File;
}

sub PushFileInfo {
	local( $_ ) = @_;
	
	printf( "%d:pushing FileInfo %s -> $_\n",
		$#IncludeList + 1,
		$FileInfo->{ InFile } || '(undef)'
	) if( $Debug >= 2 );
	
	if( $FileInfo->{ InFile }){
		$FileInfo->{ RewindPtr }	= tell( $FileInfo->{ In } );
		$FileInfo->{ LineCnt }		= $.;
		close( $FileInfo->{ In } );
	}
	
	push( @IncludeList, $FileInfo );
	
	$FileInfo = {
		InFile		=> $_,
		DispFile	=> $_,
	};
}

sub PopFileInfo {
	close( $FileInfo->{ In }) if( $FileInfo->{ In });
	
	print( "$#IncludeList:poping FileInfo $FileInfo->{ InFile } -> " ) if( $Debug >= 2 );
	$FileInfo = pop( @IncludeList );
	print(( $FileInfo->{ InFile } || '(undef)' ) . "\n" ) if( $Debug >= 2 );
	
	if( $FileInfo->{ InFile }){
		open( $FileInfo->{ In }, "< $FileInfo->{ InFile }" );
		seek( $FileInfo->{ In }, $FileInfo->{ RewindPtr }, SEEK_SET );
	}
	
	$. = $FileInfo->{ LineCnt };
	$CppInfo->{ ResetLinePos } = $.;
}

sub Include {
	local( $_ ) = @_;
	
	$_ = ExpandMacro( $_, $EX_CPP | $EX_STR );
	
	if( /<.+>/ ){
		PrintRTL( "\n" );
		return;
	}
	
	$_ = SearchIncludeFile( $1 ) if( /"(.*?)"/ );
	
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

### Scpp �ѡ��� ##############################################################

sub ScppParser {
	local( $_ );
	
	foreach $_ ( @{ $CppInfo->{ ScppInfo }} ){
		
		$FileInfo->{ LineCnt } = $_->{ LineCnt };
		
		if( $_->{ Keyword } eq 'SC_MODULE' ){
			StartModule( $_ );
		}elsif( $_->{ Keyword } eq '$ScppSensitive' ){
			GetSensitive( $_ );
		}elsif( $_->{ Keyword } eq '$ScppInstance' ){
			DefineInst( $_ );
		}elsif( $_->{ Keyword } =~ /^\$Scpp/ ){
			#Error( "unknown scpp directive \"$_->{ Keyword }\"" );
		}
	}
}

### Scpp �ǽ����� ############################################################

sub OutputToLineCnt {
	my( $fpIn, $fpOut, $LineCnt ) = @_;
	local $_;
	
	while( !defined( $LineCnt ) || $fpIn->input_line_number() < $LineCnt ){
		if( !( $_ = <$fpIn> )){
			Error( "internal error: OutputToLine(): no more line" ) if( $LineCnt );
			last;
		}
		print $fpOut $_ if( defined( $fpOut ));
	}
}

sub ScppOutput {
	my( $InFile, $OutFile ) = @_;
	local( $_ );
	my $fpIn;
	my $fpOut;
	my $SkipToEnd = 0;
	my $Scpp;
	my( $Wire, $Type );
	my $indent;
	my $i;
	my $tmp;
	my $ModInfo;
	
	if( !open( $fpIn, "< $InFile" )){
		Error( "can't open file \"$InFile\"" );
		return;
	}
	
	if( !open( $fpOut, "> $OutFile" )){
		Error( "can't open file \"$OutFile\"" );
		close( $fpIn );
		return;
	}
	
	foreach $Scpp ( @{ $CppInfo->{ ScppInfo }} ){
		
		if( $SkipToEnd ){
			$SkipToEnd = 0;
			
			if( $Scpp->{ Keyword } eq '$ScppEnd' ){
				# ScppEnd ľ���ޤǥ����å�
				OutputToLineCnt( $fpIn, undef, $Scpp->{ LineCnt } - 1 );
				OutputToLineCnt( $fpIn, $fpOut, $Scpp->{ LineCnt });
				next;
			}
			
			# ScppEnd ��̵�����顼
			Error( "unexpected scpp directive: $Scpp->{ Keyword }" );
		}
		
		# $Scpp ľ���ޤǽ���
		OutputToLineCnt( $fpIn, $fpOut, $Scpp->{ LineCnt } - 1 );
		
		# $Scpp �� Begin ��Ĥ���
		$_ = <$fpIn>;
		/^(\s*)/; $indent = $1;
		
		if( $Scpp->{ Keyword } ne 'SC_MODULE' ){
			$SkipToEnd = ( $Scpp->{ Line } =~ /\bBegin\s*$/ ) ? 1 : 0;
			if( !$SkipToEnd ){
				s#\s*\*/\s*$# Begin */\n# || s/\s*$/ Begin\n/;
			}
		}
		print $fpOut $_;
		
		$ModInfo = $ModuleInfo->{ $Scpp->{ ModuleName }};
		$FileInfo->{ LineCnt } = $Scpp->{ LineCnt };
		
		if( $Scpp->{ Keyword } eq '$ScppSensitive' ){
			# ���󥷥ƥ��ӥƥ��ꥹ�Ƚ���
			foreach $_ ( sort keys %{ $ModInfo->{ sensitivity }}){
				$tmp = $ModInfo->{ sensitivity }{ $_ };
				$tmp =~ s/^/$indent/mg;
				print $fpOut $tmp;
			}
			
		}elsif( $Scpp->{ Keyword } eq '$ScppInstance' ){
			# ��ư���󥹥���
			$tmp = $ModInfo->{ instance }{ $Scpp->{ Arg }[ 1 ]};
			$tmp =~ s/^/$indent/mg;
			print $fpOut $tmp;
			
		}elsif( $Scpp->{ Keyword } eq '$ScppAutoMember' ){
			$ModInfo->{ SimModule } = 0;
			
			# in/out/signal �������
			foreach $Wire ( @{ $ModInfo->{ WireList }} ){
				$Type = QueryWireType( $Wire, "d" );
				if( $Type ne '' ){
					print $fpOut "${indent}sc_$Type$Wire->{ type } $Wire->{ name };\n";
				}
			}
			
			# ���饹����� function �Υץ�ȥ��������
			foreach $_ ( sort keys %{ $ModInfo->{ prototype }}){
				print $fpOut "${indent}void $_( void );\n";
			}
			
		}elsif( $Scpp->{ Keyword } eq '$ScppAutoMemberSim' ){
			# in/out/signal ������� (sim)
			$ModInfo->{ SimModule } = 1;
			
			foreach $Wire ( @{ $ModInfo->{ WireList }} ){
				if( QueryWireType( $Wire, "d" )){
					$tmp = $Wire->{ type } eq '_clk' ? 'sc_clock' : "sc_signal$Wire->{ type }";
					print $fpOut "${indent}$tmp $Wire->{ name };\n";
				}
			}
		}elsif( $Scpp->{ Keyword } eq '$ScppSigTrace' ){
			# signal trace ����
			print $fpOut "${indent}#ifdef VCD_WAVE\n";
			foreach $Wire ( @{ $ModInfo->{ WireList }} ){
				print $fpOut "${indent}sc_trace( trace_f, $Wire->{ name }, std::string( this->name()) + \".$Wire->{ name }\" );\n";
			}
			print $fpOut "${indent}#endif // VCD_WAVE\n";
		}elsif( $Scpp->{ Keyword } eq '$ScppInitializer' ){
			# ����̾���� (�������)
			
			$i = $#{ $ModInfo->{ WireList }} + 1;
			
			foreach $Wire ( @{ $ModInfo->{ WireList }} ){
				printf(
					$fpOut "${indent}$Wire->{ name }( \"$Wire->{ name }\" )%s\n",
					--$i ? ',' : ''
				);
			}
			
		}elsif( $Scpp->{ Keyword } =~ /^\$Scpp/ ){
			#Error( "unknown scpp directive \"$Scpp->{ Keyword }\"" );
		}
		
		# $ScppEnd ��Ĥ���
		if( !$SkipToEnd && $Scpp->{ Keyword } ne 'SC_MODULE' ){
			# ����ǥ�ȼ���
			print $fpOut "$indent// \$ScppEnd\n";
		}
	}
	
	OutputToLineCnt( $fpIn, $fpOut );
	
	close( $fpIn );
	close( $fpOut );
}

### Start of the module #####################################################

sub StartModule {
	local( $_ );
	my( $Scpp ) = @_;
	
	# �� module �� wire / port �ꥹ�Ȥ�get
	
	my $ModuleIO = GetModuleIO( $Scpp->{ ModuleName }, $FileInfo->{ DispFile }, 1 );
	
	# input/output ʸ 1 �Ԥ��Ȥν���
	
	my( $InOut, $Type, $Name, $Attr, $Ary );
	foreach $_ ( @$ModuleIO ){
		( $InOut, $Type, $Name )	= split( /\t/, $_ );
		
		$Attr = $InOut eq "in"		? $ATTR_IN		:
				$InOut eq "out"		? $ATTR_OUT		:
				$InOut eq "inout"	? $ATTR_INOUT	:
				$InOut eq "signal"	? $ATTR_WIRE	: 0;
		
		RegisterWire( $Name, $Type, $ATTR_DEF | $Attr, $Ary, $Scpp->{ ModuleName } );
	}
}

### ���󥷥ƥ��ӥƥ��ꥹ�ȼ��� ###############################################

sub GetSensitive {
	local $_;
	my( $Scpp ) = @_;
	my $PrevCppInfo;
	
	if( !defined( $Scpp->{ Arg })){
		Error( "syntax error (ScppSensitive)" );
		return;
	}
	
	foreach $_ ( @{ $Scpp->{ Arg }}){
		$_ = ExpandMacro( $_, $EX_STR );
		s/^"(.*)"$/$1/;
		
		$_ = ( $_ eq '.' ) ? $FileInfo->{ DispFile } : SearchIncludeFile( $_ );
		
		PushFileInfo( $_ );
		$PrevCppInfo = $CppInfo;
		
		GetSensitiveSub( $_, $Scpp );
		
		$CppInfo = $PrevCppInfo;
		PopFileInfo();
	}
}

sub GetSensitiveSub {
	my( $File, $Scpp ) = @_;
	local $_;
	
	return '' if( !CPreprocessor( $File ));;
	
	my $ModuleName = $Scpp->{ ModuleName };
	my $SubModule = '';
	my $Line;
	my $Process;
	my $Arg;
	my @Arg;
	my $FuncName;
	my $ModuleBuf;
	
	while( $_ = ReadLine()){
		
		$ModuleBuf .= $_ if( $SubModule );
		
		if( s/\bSC_MODULE\s*\(\s*(.+?)\s*\)// ){
			$SubModule = $1;
			$SubModule =~ s/\s+//g;
			
			$ModuleBuf = $_;
			
		}elsif( /\$Scpp(Method|Thread|Cthread)\s*($OpenClose)?/ ){
			( $Process, $Arg ) = ( uc( $1 ), defined( $2 ) ? $2 : '' );
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
			
			# { �����ʬΥ
			( $_, $Line ) = /(.*?)({.*)/;
			
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
			
			if( !$FuncName ){
				Error( "can't find function name" );
				next;
			}
			
			# Method �Υ��󥷥ƥ��ӥƥ���ưǧ��
			if( $Process eq 'METHOD' && $#Arg < 0 ){
				$_ = $Line;
				$Arg = {};
				
				while( 1 ){
					last if( /^$OpenCloseBlock/ );
					
					if( !( $Line = ReadLine())){
						Error( "} or ; not found (GetSensitive)" );
						last;
					}
					$_ .= $Line;
				}
				
				s/($CSymbol)\.read\s*\(\s*\)/$Arg->{ $1 } = 1/ge;
				@Arg = sort keys %$Arg;
			}
			
			# ���󥷥ƥ��ӥƥ���������
			if( $Process eq 'CTHREAD' ){
				Error( 'invalid argument $ScppCthread()' ) if( $#Arg != 0 && $#Arg != 2 );
				
				$_ = "SC_CTHREAD( $FuncName, $Arg[0] );\n";
				$_ .= "reset_signal_is( $Arg[1], $Arg[2] );\n" if( $#Arg >= 2 );
				
				$ModuleInfo->{ $ModuleName }{ sensitivity }{ $FuncName } = "$_\n";
			}else{
				$ModuleInfo->{ $ModuleName }{ sensitivity }{ $FuncName } =
					"SC_$Process( $FuncName );\nsensitive << " . join( ' << ', @Arg ) . ";\n\n";
			}
			
			print( "Sens: $ModuleName $FuncName: $ModuleInfo->{ $ModuleName }{ sensitivity }{ $FuncName }\n" ) if( $Debug >= 3 );
			
			# ���饹����������Ƥ��� function ��Ͽ
			$ModuleInfo->{ $ModuleName }{ prototype }{ $FuncName } = 1 if( !$SubModule );
		}
		
		# module �ν�������
		if( $SubModule && $ModuleBuf =~ /^[\{]*$OpenCloseBlock/ ){
			print( "$SubModule end @ $.\n" ) if( $Debug >= 3 );
			$SubModule = '';
			undef $ModuleBuf;
		}
	}
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
	local $_;
	my( $Scpp ) = @_;
	
	my(
		$Port,
		$Wire,
		$Attr,
		$InOut,
		$Type,
		$Ary,
	);
	
	my $SkelList = [];
	
	my $LineNo = $.;
	
	# ��������
	if( !defined( $Scpp->{ Arg }) || $#{ $Scpp->{ Arg }} < 2 ){
		Error( 'invalid argument ($ScppInstance)' );
		return;
	}
	
	print( "DefineInst:" . join( ", ", @{ $Scpp->{ Arg }} ) . "\n" ) if( $Debug >= 3 );
	
	# get module name, module inst name, module file
	my $SubModuleName = $Scpp->{ Arg }[ 0 ];
	my $SubModuleInst = $Scpp->{ Arg }[ 1 ];
	my $ModuleFile = ExpandMacro( $Scpp->{ Arg }[ 2 ], $EX_STR );
	
	my $Buf = "$SubModuleInst = new $SubModuleName( \"$SubModuleInst\" );\n";
	
	$ModuleFile =~ s/^"(.*)"$/$1/;
	$ModuleFile = ( $ModuleFile eq "." ) ? $FileInfo->{ DispFile } : SearchIncludeFile( $ModuleFile );
	
	# read port->wire tmpl list
	ReadSkelList( $SkelList, $Scpp->{ Arg });
	
	# get sub module's port list
	$SubModuleName =~ s/\s*\<.*//;
	my $ModuleIO = GetModuleIO( $SubModuleName, $ModuleFile );
	
	# input/output ʸ 1 �Ԥ��Ȥν���
	
	foreach $_ ( @$ModuleIO ){
		
		( $InOut, $Type, $Port, $Ary ) = split( /\t/, $_ );
		next if( $InOut !~ /^(?:in|out|inout)$/ );
		
		( $Wire, $Attr ) = ConvPort2Wire( $SkelList, $Port, $Type, $InOut );
		
		if( !( $Attr & $ATTR_NC )){
			next if( $Attr & $ATTR_IGNORE );
			
			# wire list ����Ͽ
			
			if( $Wire !~ /^\d/ ){
				$Attr |= ( $InOut eq "in" )		? $ATTR_REF		:
						 ( $InOut eq "out" )	? $ATTR_FIX		:
												  $ATTR_BYDIR	;
				
				RegisterWire(
					$Wire,
					$Type,
					$Attr,
					undef,	# ��Ķ����
					$Scpp->{ ModuleName }
				);
			}elsif( $Wire =~ /^\d+$/ ){
				# �������������ꤵ�줿��硤bit��ɽ����Ĥ���
				# ���׽���
				#$Wire = sprintf( "%d'd$Wire", GetBusWidth2( $Type ));
			}
		}
		
		$Buf .= $SubModuleInst . "->$Port( $Wire );\n";
	}
	
	$ModuleInfo->{ $Scpp->{ ModuleName }}{ instance }{ $SubModuleInst } = $Buf;
	
	# SkelList ̤���ѷٹ�
	
	WarnUnusedSkelList( $SkelList, $SubModuleInst, $LineNo );
}

### search module & get IO definition ########################################

sub GetModuleIO {
	my( $ModuleName, $ModuleFile, $Self ) = @_;
	
	PushFileInfo( $ModuleFile );
	my $PrevCppInfo = $CppInfo;
	
	my $Port = GetModuleIOSub( $ModuleName, $ModuleFile, $Self );
	
	$CppInfo = $PrevCppInfo;
	PopFileInfo();
	
	$Port;
}

sub GetModuleIOSub{
	local $_;
	my $Port = [];
	
	my( $ModuleName, $ModuleFile, $Self ) = @_;
	
	printf( "GetModuleIO: $ModuleName, $ModuleFile\n" ) if( $Debug >= 2 );
	
	my $fp = CPreprocessor( $ModuleFile );
	return $Port if( !$fp );
	
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
	
	if( $bFound == 0 ){
		Error( "can't find SC_MODULE \"$ModuleName\@$ModuleFile\"" );
		return $Port;
	}
	
	if( $bFound == 1 ){
		Error( "can't find end of SC_MODULE \"$ModuleName\@$ModuleFile\"" );
		return $Port;
	}
	
	$_ = $Buf;
	
	# $Self �⡼�ɤλ���$ScppAutoMember ���줿��Τ�ǧ������Ȥޤ����ΤǺ��
	if( $Self ){
		s/\$ScppAutoMember(?:Sim)?\s+Begin\b.*?\$ScppEnd//s;
	}
	
	s/\$Scpp.*//g;
	$_ = ExpandMacro( $_, $EX_SP );
	s/([\{\};])+/\n/g;
	#printf( "GetModuleIO: Buf0 >>>>>>>>\n$_\n<<<<<<<<<<<\n" );
	
	my $io;
	my $Type;
	my $Name;
	my $Ary;
	my @name;
	
	foreach $_ ( split( /\n+/, $_ )){
		next if( !/^sc_(in|in_clk|out|inout|signal)\b\s*(.*)/ );
		
		# in / out / signal ��Ƚ��
		# sc_in_clk �ϡ� io=sc_in type=_clk �ˤ���
		
		( $io, $_ ) = ( $1, $2 );
		
		# ������
		if( $io eq 'in_clk' ){
			$io		= 'in';
			$Type	= '_clk';
		}elsif( /^($OpenCloseType)(.*)/ ){
			( $Type, $_ ) = ( $1, $2 );
		}else{
			$Type = '';
		}
		
		# �ѿ�̾����
		foreach $_ ( split( /,/, $_ )){
			( $Name, $Ary ) = /^($CSymbol)(.*)/ ? ( $1, $2 ) : ( $_, '' );
			push( @$Port, "$io	$Type	$Name	$Ary" );
		}
	}
	
	print "GetModuleIO: >>>>>>>>\n" . join( "\n", @$Port ) . "\n<<<<<<<<<<<\n" if( $Debug >= 3 );
	
	return $Port;
}

### read port/wire tmpl list #################################################

sub ReadSkelList{
	
	local $_;
	my( $SkelList, $List ) = @_;
	my(
		$Port,
		$Wire,
		$Attr,
		$AttrLetter,
		$i,
		$tmp
	);
	
	for( $i = 3; $i <= $#{ $List }; ++$i ){
		
		# "..." ����
		$_ = ExpandMacro( $List->[ $i ], $EX_STR );
		$_ = ExpandMacro( $1 ) if( /^"(.*)"$/ );
		
		undef $Port;
		
		if( /^$CSymbol->($CSymbol)\(($CSymbol)\)/ ){
			# hoge->fuga( piyo )
			( $Port, $Wire, $AttrLetter ) = ( $1, $2, '' );
		}elsif( /^(\W)(.*?)\1(.*?)\1(.*)$/ ){
			# /hoge/fuga/opt
			( $Port, $Wire, $AttrLetter, $tmp ) = ( $2, $3, $4, $1 );
			$Port = '(.*)' if( $Port eq '' );
			
			undef $Port if( $AttrLetter =~ /\Q$tmp\E/ );
		}elsif( /^$CSymbol$/ ){
			( $Port, $Wire, $AttrLetter ) = ( $_, $_, '' );
		}
		
		if( !$Port ){
			Error( "syntax error (\$ScppInstance: \"$_\")" );
			next;
		}
		
		if( $Wire =~ /^[mbu]?(?:np|nc|w|i|o|io|u|\*d)$/ ){
			$AttrLetter = $Wire;
			$Wire = "";
		}
		
		# attr
		
		$Attr = 0;
		
		$Attr |= $ATTR_USED			if( $AttrLetter =~ /u/ );
		$Attr |=
			( $AttrLetter =~ /np$/ ) ? $ATTR_DEF	:
			( $AttrLetter =~ /nc$/ ) ? $ATTR_NC		:
			( $AttrLetter =~ /w$/  ) ? $ATTR_WIRE	:
			( $AttrLetter =~ /i$/  ) ? $ATTR_IN		:
			( $AttrLetter =~ /o$/  ) ? $ATTR_OUT	:
			( $AttrLetter =~ /io$/ ) ? $ATTR_INOUT	:
			( $AttrLetter =~ /d$/  ) ? $ATTR_IGNORE	: 0;
		
		push( @$SkelList, {
			port => $Port,
			wire => $Wire,
			attr => $Attr,
		} );
		
		print( "skel: '$_' /$Port/$Wire/$Attr\n" ) if( $Debug >= 3 );
	}
}

### tmpl list ̤���ѷٹ� #####################################################

sub WarnUnusedSkelList{
	
	my( $SkelList, $LineNo );
	local( $_ );
	( $SkelList, $_, $LineNo ) = @_;
	my( $Skel );
	
	foreach $Skel ( @$SkelList ){
		if( !( $Skel->{ attr } & $ATTR_USED )){
			Warning( "unused template ( $Skel->{ port } --> $Skel->{ wire } \@ $_ )", $LineNo );
		}
	}
}

### convert port name to wire name ###########################################

sub ConvPort2Wire {
	
	my( $SkelList, $Port, $Type, $InOut ) = @_;
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
	
	foreach $Skel ( @$SkelList ){
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
	
	my( $Name, $Type, $Attr, $Ary, $ModuleName ) = @_;
	my( $Wire );
	
	if( defined( $Wire = $ModuleInfo->{ $ModuleName }{ WireListHash }{ $Name } )){
		# ���Ǥ���Ͽ�Ѥ�
		
		# Type ����äƤ���� size mismatch �ٹ�
		if( $Wire->{ type } ne $Type ){
			Warning( "unmatch port type ( $ModuleName.$Name $Type != $Wire->{ type } )" );
		}
		
		# ξ�� inout ���ʤ顤��Ͽ����ۤ��� REF ���ѹ�
		
		if( $Wire->{ attr } & $Attr & $ATTR_INOUT ){
			$Attr |= $ATTR_REF;
		}
		
		# multiple driver �ٹ�
		
		if( $Wire->{ attr } & $Attr & $ATTR_FIX ){
			Warning( "multiple driver ($Name)" );
		}
		
		$Wire->{ attr } |= $Attr;
		print( "RegWire: upd: $ModuleName.$Name\n" ) if( $Debug >= 3 );
		
	}else{
		# ������Ͽ
		
		push( @{ $ModuleInfo->{ $ModuleName }{ WireList }}, $Wire = {
			name	=> $Name,
			type	=> $Type,
			attr	=> $Attr
		} );
		
		$ModuleInfo->{ $ModuleName }{ WireListHash }{ $Name } = $Wire;
		print( "RegWire: add: $ModuleName.$Name\n" ) if( $Debug >= 3 );
	}
}

### query wire type & returns "in/out/inout" #################################
# $Mode eq "d" �� in/out/wire ���ʸ�⡼��

sub QueryWireType{
	
	my( $Wire, $Mode ) = @_;
	my $Attr = $Wire->{ attr };
	
	return ''	if( $Attr & $ATTR_DEF  && $Mode eq 'd' );
	return 'in'		if( $Attr & $ATTR_IN );
	return 'out'	if( $Attr & $ATTR_OUT );
	return 'inout'	if( $Attr & $ATTR_INOUT );
	return 'signal' if( $Attr & $ATTR_WIRE );
	return 'inout'	if(( $Attr & ( $ATTR_BYDIR | $ATTR_REF | $ATTR_FIX )) == $ATTR_BYDIR );
	return 'in'		if(( $Attr & ( $ATTR_REF | $ATTR_FIX )) == $ATTR_REF );
	return 'out'	if(( $Attr & ( $ATTR_REF | $ATTR_FIX )) == $ATTR_FIX );
	return 'signal' if(( $Attr & ( $ATTR_REF | $ATTR_FIX )) == ( $ATTR_REF | $ATTR_FIX ));
	
	return '';
}

### output wire list #########################################################

sub OutputWireList{
	
	my ( $ListFile ) = @_;
	
	my(
		@WireListBuf,
		
		$WireCntUnresolved,
		$WireCntAdded,
		$Attr,
		$Type,
		$Wire,
		$ModuleName,
	);
	my $fp;
	
	if( $Debug ){
		if( !open( $fp, "> $ListFile" )){
			Error( "can't open file \"$ListFile\"" );
			return;
		}
	}
	
	foreach $ModuleName ( sort keys %$ModuleInfo ){
		
		undef @WireListBuf;
		$WireCntUnresolved = 0;
		$WireCntAdded	   = 0;
		
		foreach $Wire ( @{ $ModuleInfo->{ $ModuleName }{ WireList }} ){
			
			$Attr = $Wire->{ attr };
			$Type = QueryWireType( $Wire, "" );
			
			$Type =	$Type eq "in"		? "I" :
					$Type eq "out"		? "O" :
					$Type eq "inout"	? "B" :
					$Type eq "signal"	? "W" :
										  "-" ;
			
			++$WireCntUnresolved if( !( $Attr & ( $ATTR_BYDIR | $ATTR_FIX | $ATTR_REF )));
			if(
				!$ModuleInfo->{ $ModuleName }{ SimModule } &&
				!( $Attr & $ATTR_DEF ) && ( $Type =~ /[IOCB]/ )
			){
				++$WireCntAdded;
				Warning( "'$ModuleName.$Wire->{ name }' is undefined, generated automatically" );
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
		}
		
		if( $Debug ){
			@WireListBuf = sort( @WireListBuf );
			
			printf( "Wire info : Unresolved:%3d / Added:%3d ( $ModuleName\@$FileInfo->{ DispFile } )\n",
				$WireCntUnresolved, $WireCntAdded );
			
			print( $fp "*** $ModuleName wire list ***\n" );
			print( $fp @WireListBuf );
		}
	}
	close( $fp ) if( $Debug );
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
			print( "...included at $_->{ DispFile }($_->{ LineCnt }):\n" );
		}
	}
	
	printf( "$FileInfo->{ DispFile }(%d): $_\n",
		defined( $LineNo )	? $LineNo :
		$FileInfo->{ In }	? $. :
							  $FileInfo->{ LineCnt }
	);
}
