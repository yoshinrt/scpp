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
my $ATTR_REF		= $enum;				# wire が参照された
my $ATTR_FIX		= ( $enum <<= 1 );		# wire に出力された
my $ATTR_BYDIR		= ( $enum <<= 1 );		# inout で接続された
my $ATTR_IN			= ( $enum <<= 1 );		# 強制 I
my $ATTR_OUT		= ( $enum <<= 1 );		# 強制 O
my $ATTR_INOUT		= ( $enum <<= 1 );		# 強制 IO
my $ATTR_WIRE		= ( $enum <<= 1 );		# 強制 W
my $ATTR_MD			= ( $enum <<= 1 );		# multiple drv ( 警告抑制 )
my $ATTR_DEF		= ( $enum <<= 1 );		# ポート・信号定義済み
my $ATTR_DC_WEAK_W	= ( $enum <<= 1 );		# Bus Size は弱めの申告警告を抑制
my $ATTR_WEAK_W		= ( $enum <<= 1 );		# Bus Size は弱めの申告
my $ATTR_USED		= ( $enum <<= 1 );		# この template が使用された
my $ATTR_IGNORE		= ( $enum <<= 1 );		# `ifdef 切り等で本来無いポートを無視する等
my $ATTR_NC			= ( $enum <<= 1 );		# 入力 0 固定，出力 open

$enum = 0;
my $BLKMODE_NORMAL	= $enum++;	# ブロック外
my $BLKMODE_IF		= $enum++;	# if ブロック
my $BLKMODE_ELSE	= $enum++;	# else ブロック

$enum = 1;
my $EX_CPP			= $enum;		# CPP マクロ展開
my $EX_STR			= $enum <<= 1;	# 文字列リテラル
my $EX_RMSTR		= $enum <<= 1;	# 文字列リテラル削除
my $EX_COMMENT		= $enum <<= 1;	# コメント
my $EX_RMCOMMENT	= $enum <<= 1;	# コメント削除

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

my $BlockNoOutput	= 0;
my $ResetLinePos	= 0;

# option
my $CppOnly			= 0;
my @IncludeList;
my $Debug	= 0;

# 定義テーブル関係
my $CppInfo;
my $FileInfo;
my $ModuleName;
my @ScppInfo;
my $ModuleInfo;

main();
exit( $ErrorCnt != 0 );

### main procedure ###########################################################

sub main{
	local( $_ );
	
	if( $#ARGV < 0 ){
		print( "usage: vpp.pl [-vrE] [-I<path>] [-D<def>[=<val>]] <Def file>\n" );
		return;
	}
	
	# -DMACRO setup
	
	while( 1 ){
		$_ = $ARGV[ 0 ];
		
		if    ( /^-I(.*)/		){ push( @INC, $1 );
		}elsif( /^-D(.+?)=(.+)/	){ AddCppMacro( $1, $2 );
		}elsif( /^-D(.+)/		){ AddCppMacro( $1 );
		}elsif( /^-/			){
			while( s/v// ){ ++$Debug; }
			$CppOnly = 1 if( /E/ );
		}else					 { last;
		}
		shift( @ARGV );
	}
	
	# set up default file name
	
	my $SrcFile = $ARGV[ 0 ];
	   $SrcFile =~ /(.*?)(\.def)?(\.[^\.]+)$/;
	
	my $DstFile  = "$1$3"; $DstFile  = "$1_top$3" if( $DstFile eq $SrcFile );
	my $ListFile = "$1.list";
	
	return if( !CPreprocessor( $SrcFile ));
	# ★ $FileInfo->{ In } は使用しないので要 close
	
	if( $CppOnly ){
		my $fp = $FileInfo->{ In };
		while( <$fp> ){
			print( $Debug ? $_ : ExpandMacro( $_, $EX_STR | $EX_COMMENT ));
		}
	}else{
		# vpp
		unlink( $ListFile );
		
		ScppParser();
		ScppOutput( $SrcFile, $DstFile );
		OutputWireList( $ListFile );
	}
	
	#unlink( $CppInfo->{ OutFile } );
}

### C プリプロセッサ ########################################################

sub CPreprocessor {
	$CppInfo  = {};
	$FileInfo = {};
	
	( $FileInfo->{ InFile }) = @_;
	
	$CppInfo->{ OutFile } = 
		$Debug ? "$FileInfo->{ InFile }.cpp" : "$FileInfo->{ InFile }.cpp.$$";
	
	$FileInfo->{ DispFile } = $FileInfo->{ InFile };
	
	if( -e $CppInfo->{ OutFile }){
		print( "cpp: $CppInfo->{ OutFile } is exist, cpp skipped...\n" ) if( $Debug >= 2 );
	}else{
		# cpp 処理開始
		if( !open( $FileInfo->{ In }, "< $FileInfo->{ InFile }" )){
			Error( "can't open file \"$FileInfo->{ InFile }\"" );
			return;
		}
		
		if( !open( $CppInfo->{ Out }, "> $CppInfo->{ OutFile }" )){
			Error( "can't open file \"$CppInfo->{ OutFile }\"" );
			close( $FileInfo->{ In } );
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
		Error( "can't open file \"$FileInfo->{ InFile }\"" );
		return;
	}
	
	return $FileInfo->{ In };
}

### 1行読む #################################################################

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
			# // $Scpp のコメント外し
			s#//\s*(\$Scpp)#$1#;
		}elsif( $key =~ m#^//# ){
			# // コメント退避
			push( @{ $CppInfo->{ CommentPool }}, $1 ) if( s#(//.*)#<__COMMENT_${Cnt}__># );
		}elsif( $key eq '"' ){
			# string 退避
			if( s/((?<!\\)".*?(?<!\\)")/<__STRING_${Cnt}__>/ ){
				push( @{ $CppInfo->{ CommentPool }}, $1 );
			}else{
				Error( 'unterminated "' );
				s/"//;
			}
		}elsif( $key eq '/*$Scpp' && s#/\*\s*(\$Scpp.*?)\*/#$1#s ){
			# /* $Scpp */ コメント外し
		}elsif( $key =~ m#/\*# && s#(/\*.*?\*/)#<__COMMENT_${Cnt}__>#s ){
			# /* ... */ の組が発見されたら，置換
			push( @{ $CppInfo->{ CommentPool }}, $1 );
			$ResetLinePos = $.;
		}else{
			# /* ... */ の組が発見されないので，発見されるまで行 cat
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

# 関数マクロ用に ( ... ) を取得
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
	my $arg;
	my $tmp;
	
	while( $_ = ReadLine()){
		if( /^\s*#\s*(?:ifdef|ifndef|if|elif|else|endif|define|undef|include)\b/ ){
			
			# \ で終わっている行を連結
			while( /\\$/ ){
				if( !( $Line = ReadLine())){
					last;
				}
				$_ .= $Line;
			}
			
			$ResetLinePos = $.;
			
			# \ 削除
			s/[\t ]*\\[\x0D\x0A]+[\t ]*/ /g;
			s/\s+$//g;
			s/^\s*#\s*//;
			
			$_ = ExpandMacro( $_, $EX_RMCOMMENT );
			
			# $CppInfo->{ DefineTbl }{ $1 }{ args }:  >=0: 引数  <0: 可変引数  's': 単純マクロ
			# $CppInfo->{ DefineTbl }{ $1 }{ macro }:  マクロ定義本体
			
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
					# まだ出力していない
					$bNoOutput = !IfBlockEval( $1 );
					$BlockNoOutput &= ~1;
					$BlockNoOutput |= 1 if( $bNoOutput );
				}else{
					# もう出力した
					$BlockNoOutput |= 1;
				}
			}elsif( /^else\b/ ){
				# else
				if( $BlockMode != $BLKMODE_IF ){
					Error( "unexpected #else" );
				}elsif( $bNoOutput ){
					# まだ出力していない
					$bNoOutput = 0;
					$BlockNoOutput &= ~1;
				}else{
					# もう出力した
					$BlockNoOutput |= 1;
				}
			}elsif( /^endif\b/ ){
				# endif
				if( $BlockMode != $BLKMODE_IF ){
					Error( "unexpected #endif" );
				}else{
					last;
				}
			}elsif( !$BlockNoOutput ){
				if( /^define\s+($CSymbol)$/ ){
					# 名前だけ定義
					AddCppMacro( $1 );
				}elsif( /^define\s+($CSymbol)\s+(.+)/ ){
					# 名前と値定義
					AddCppMacro( $1, $2 );
				}elsif( /^define\s+($CSymbol)($OpenClose)\s*(.*)/ ){
					# 関数マクロ
					my( $Name, $ArgList, $Macro ) = ( $1, $2, $3 );
					
					# ArgList 整形，分割
					$ArgList =~ s/^\(\s*//;
					$ArgList =~ s/\s*\)$//;
					my( @ArgList ) = split( /\s*,\s*/, $ArgList );
					
					# マクロ内の引数を特殊文字に置換
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
					# ここには来ないと思う...
					Error( "internal error: cpp: \"$1\"\n" );
				}
			}
		}elsif( !$BlockNoOutput ){
			$_ = ExpandMacro( $_, $EX_CPP | $EX_RMCOMMENT );
			PrintRTL( $_ );
			
			# scpp directive 位置解析
			$Line = $_;
			
			s/\s+/ /g;
			s/^\s+//g;
			s/\s+$//g;
			s/\s+(\W)/$1/g;
			s/(\W)\s+/$1/g;
			
			if( /^(SC_MODULE)\(($CSymbol)\)/ ){
				push( @ScppInfo, {
					keyword	=> $1,
					module	=> $2,
					line	=> $Line,
					linecnt	=> $.
				});
				
				$CppInfo->{ ModuleName } = $2;
				
			}elsif( !/^\$Scpp(?:Method|Thread|Cthread)/ && /^(\$Scpp\w+)\s*($OpenClose)?/ ){
				( $tmp, $_ ) = ( $1, $2 );
				
				# arg 分解
				$arg = undef;
				if( $_ ){
					s/^\(\s*//;
					s/\s*\)$//;
					@$arg = split( /\s*,\s*/, $_ );
				}
				
				push( @ScppInfo, {
					keyword	=> $tmp,
					arg		=> $arg,
					module	=> $CppInfo->{ ModuleName },
					line	=> $Line,
					linecnt	=> $.,
				});
			}
		}
	}
	
	if( $_ eq '' && $BlockMode != $BLKMODE_NORMAL ){
		if( $BlockMode == $BLKMODE_IF ){
			Error( "unterminated #if", $LineCnt );
		}
	}
	
	$BlockNoOutput	>>= 1;
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
	
	if( $ResetLinePos ){
		# ここは根拠がわからない，まだバグってるかも
		if( $ResetLinePos == $. ){
			$_ .= sprintf( "# %d \"$FileInfo->{ DispFile }\"\n", $. + 1 );
		}else{
			$_ = sprintf( "# %d \"$FileInfo->{ DispFile }\"\n", $. ) . $_;
		}
		$ResetLinePos = 0;
	}
	
	print( { $CppInfo->{ Out }} $_ );
}

### CPP directive 処理 #######################################################

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

### if ブロック用 eval #######################################################

sub IfBlockEval {
	local( $_ ) = @_;
	
	# defined 置換
	s/\bdefined\s+($CSymbol)/defined( $CppInfo->{ DefineTbl }{ $1 } ) ? 1 : 0/ge;
	return Evaluate( ExpandMacro( $_, $EX_CPP | $EX_STR ));
}

### CPP マクロ展開 ###########################################################

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
					# マクロではない
					$Line .= $Name;
				}elsif( $CppInfo->{ DefineTbl }{ $Name }{ args } eq 's' ){
					# 単純マクロ
					$Line .= $CppInfo->{ DefineTbl }{ $Name }{ macro };
					$bReplaced = 1;
				}else{
					# 関数マクロ
					s/^\s+//;
					
					if( !/^\(/ ){
						# hoge( になってない
						Error( "invalid number of macro arg: $Name" );
						$Line .= $Name;
					}else{
						# マクロ引数取得
						$_ = GetFuncArg( $_ );
						
						# マクロ引数解析
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
								# 引数チェック
								$ArgNum = $CppInfo->{ DefineTbl }{ $Name }{ args };
								$ArgNum = -$ArgNum - 1 if( $ArgNum < 0 );
								
								if( !(
									$CppInfo->{ DefineTbl }{ $Name }{ args } >= 0 ?
										( $ArgNum == $#ArgList + 1 ) : ( $ArgNum <= $#ArgList + 1 )
								)){
									Error( "invalid number of macro arg: $Name" );
									$Line .= $Name . '()';
								}else{
									# 仮引数を実引数に置換
									$Line2 = $CppInfo->{ DefineTbl }{ $Name }{ macro };
									$Line2 =~ s/<__ARG_(\d+)__>/$ArgList[ $1 ]/g;
									
									# 可変引数を置換
									if( $CppInfo->{ DefineTbl }{ $Name }{ args } < 0 ){
										if( $#ArgList + 1 <= $ArgNum ){
											# 引数 0 個の時は，カンマもろとも消す
											$Line2 =~ s/,?\s*(?:##)*\s*__VA_ARGS__\s*/ /g;
										}else{
											$Line2 =~ s/(?:##\s*)?__VA_ARGS__/join( ', ', @ArgList[ $ArgNum .. $#ArgList ] )/ge;
										}
									}
									$Line .= $Line2;
									$bReplaced = 1;
								}
							}else{
								# $ArgList を全部消費しきれなかったらエラー
								Error( "invalid macro arg: $Name" );
								$Line .= $Name . '()';
							}
						}
					}
				}
			}
			$_ = $Line . $_;
		}
		
		# トークン連結演算子 ##
		$bReplaced |= s/\s*##\s*//g;
	}
	
	if( $Mode & $EX_RMSTR ){
		s/<__STRING_\d+__>/ /g;
	}elsif( $Mode & $EX_STR ){
		# 文字列化
		s/\$String($OpenClose)/Stringlize( $1 )/ge;
		
		# 文字列定数復活
		s/<__STRING_(\d+)__>/$CppInfo->{ CommentPool }[ $1 ]/g;
		
		# 文字列リテラル連結
		1 while( s/((?<!\\)".*?)(?<!\\)"\s*"(.*?(?<!\\)")/$1$2/g );
	}
	
	# コメント
	if( $Mode & $EX_RMCOMMENT ){
		s/<__COMMENT_\d+__>/ /g;
	}elsif( $Mode & $EX_COMMENT ){
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

### ファイル include #########################################################

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
	};
}

sub PopFileInfo {
	close( $FileInfo->{ In });
	
	print( "poping FileInfo $FileInfo->{ InFile } -> " ) if( $Debug >= 2 );
	$FileInfo = pop( @IncludeList );
	print( "$FileInfo->{ InFile }\n" ) if( $Debug >= 2 );
	
	open( $FileInfo->{ In }, "< $FileInfo->{ InFile }" );
	seek( $FileInfo->{ In }, $FileInfo->{ RewindPtr }, SEEK_SET );
	
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

### 環境変数展開 #############################################################

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

### Scpp パーザ ##############################################################

sub ScppParser {
	local( $_ );
	
	foreach $_ ( @ScppInfo ){
		if( $_->{ keyword } eq 'SC_MODULE' ){
			StartModule( $_->{ module });
		}elsif( $_->{ keyword } eq '$ScppPutSensitive' ){
			GetSensitive( $_ );
		}elsif( $_->{ keyword } eq '$ScppInstance' ){
			DefineInst( $_ );
		}elsif( $_->{ keyword } =~ /^\$Scpp/ ){
			#Error( "unknown scpp directive \"$_->{ keyword }\"" );
		}
	}
}

### Scpp 最終出力 ############################################################

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
	
	if( !open( $fpIn, "< $InFile" )){
		Error( "can't open file \"$InFile\"" );
		return;
	}
	
	if( !open( $fpOut, "> $OutFile" )){
		Error( "can't open file \"$OutFile\"" );
		close( $fpIn );
		return;
	}
	
	foreach $Scpp ( @ScppInfo ){
		
		if( $SkipToEnd ){
			$SkipToEnd = 0;
			
			if( $Scpp->{ keyword } eq '$ScppEnd' ){
				# ScppEnd 直前までスキップ
				OutputToLineCnt( $fpIn, undef, $Scpp->{ linecnt } - 1 );
				OutputToLineCnt( $fpIn, $fpOut, $Scpp->{ linecnt });
				next;
			}
			
			# ScppEnd が無いエラー
			Error( "unexpected scpp directive: $Scpp->{ keyword }" );
		}
		
		# $Scpp 直前まで出力
		OutputToLineCnt( $fpIn, $fpOut, $Scpp->{ linecnt } - 1 );
		
		# $Scpp に Begin をつける
		$_ = <$fpIn>;
		if( $Scpp->{ keyword } ne 'SC_MODULE' ){
			$SkipToEnd = ( $Scpp->{ line } =~ /\bBegin\s*$/ ) ? 1 : 0;
			if( !$SkipToEnd ){
				s#\s*\*/\s*$# Begin */\n# || s/\s*$/ Begin\n/;
			}
		}
		print $fpOut $_;
		
		if( $Scpp->{ keyword } eq 'SC_MODULE' ){
			$ModuleName = $Scpp->{ module };
			
		}elsif( $Scpp->{ keyword } eq '$ScppPutSensitive' ){
			print $fpOut $ModuleInfo->{ $ModuleName }{ sensitivity };
			
		}elsif( $Scpp->{ keyword } eq '$ScppInstance' ){
			print $fpOut $ModuleInfo->{ $ModuleName }{ instance }{ $Scpp->{ arg }[ 1 ]};
			
		}elsif( $Scpp->{ keyword } eq '$ScppAutoSignal' ){
			# in/out/signal 宣言出力
			
			$Scpp->{ line } =~ /^(\s*)/;
			$indent = $1;
			
			foreach $Wire ( @{ $ModuleInfo->{ $ModuleName }{ WireList }} ){
				$Type = QueryWireType( $Wire, "d" );
				if( $Type eq "in" || $Type eq "out" || $Type eq "inout" ){
					print $fpOut "${indent}sc_$Type$Wire->{ type } $Wire->{ name };\n";
				}
			}
		}elsif( $Scpp->{ keyword } =~ /^\$Scpp/ ){
			#Error( "unknown scpp directive \"$Scpp->{ keyword }\"" );
		}
		
		# $ScppEnd をつける
		if( !$SkipToEnd && $Scpp->{ keyword } ne 'SC_MODULE' ){
			# インデント取得
			$Scpp->{ line } =~ /^(\s*)/;
			print $fpOut "$1// \$ScppEnd\n";
		}
	}
	
	OutputToLineCnt( $fpIn, $fpOut );
	
	close( $fpIn );
	close( $fpOut );
}

### Start of the module #####################################################

sub StartModule{
	local( $_ );
	( $ModuleName ) = @_;
	
	# 親 module の wire / port リストをget
	
	my $ModuleIO = GetModuleIO( $ModuleName, $FileInfo->{ DispFile });
	
	# input/output 文 1 行ごとの処理
	
	my( $InOut, $Type, $Name, $Attr );
	foreach $_ ( @$ModuleIO ){
		( $InOut, $Type, $Name )	= split( /\t/, $_ );
		
		$Attr = $InOut eq "sc_in"		? $ATTR_IN		:
				$InOut eq "sc_out"		? $ATTR_OUT		:
				$InOut eq "sc_inout"	? $ATTR_INOUT	:
				$InOut eq "sc_signal"	? $ATTR_WIRE	: 0;
		
		RegisterWire( $Name, $Type, $ATTR_DEF | $Attr, $ModuleName );
	}
}

### センシティビティリスト取得 ###############################################

sub GetSensitive {
	local $_;
	my( $Scpp ) = @_;
	my $Buf = '';
	
	if( !defined( $Scpp->{ arg })){
		Error( "syntax error (ScppSensitive)" );
		return;
	}
	
	foreach $_ ( @{ $Scpp->{ arg }}){
		$_ = ExpandMacro( $_, $EX_STR );
		s/^"(.*)"$/$1/;
		
		$_ = $FileInfo->{ DispFile } if( $_ eq '.' );
		
		PushFileInfo( $_ );
		$Buf .= GetSensitiveSub( $_ );
		PopFileInfo();
	}
	
	# インデント
	
	$Scpp->{ line } =~ /^(\s*)/;
	my $indent = $1;
	
	$Buf =~ s/\n/\n$indent/g;
	$Buf =~ s/[^\n]+$//;
	$ModuleInfo->{ $ModuleName }{ sensitivity } = "$indent$Buf";
	
	print( ">>>>>$ModuleName sensitive:\n$Buf<<<<<<<<<<\n" ) if( $Debug >= 3 );
}

sub GetSensitiveSub {
	my( $File ) = $_;
	local $_;
	
	my $PrevCppInfo = $CppInfo;
	return if( !CPreprocessor( $File ));
	
	my $SubModule;
	my $Line;
	my $Process;
	my $Arg;
	my @Arg;
	my $FuncName;
	my $Buf = '';
	
	while( $_ = ReadLine()){	# ★マクロ展開必要かも，要検討
		
		if( /\bSC_MODULE\s*\(\s*(.+?)\s*\)/ ){
			$SubModule = $1;
			$SubModule =~ s/\s+//g;
		}elsif( /\$Scpp(Method|Thread|Cthread)\s*($OpenClose)/ ){
			( $Process, $Arg ) = ( uc( $1 ), $2 );
			$Arg =~ s/^\s*\(\s*//;
			$Arg =~ s/\s*\)\s*$//;
			@Arg = split( /\s*,\s*/, $Arg );
			
			$_ = '';
			
			# '{' ';' まで取得
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
			
			# クラス名あり，void hoge<fuga>::piyo( void )
			if( /^(\S+?)::($CSymbol)/ && $1 eq $ModuleName ){
				$FuncName = $2;
			}
			
			# クラス宣言内
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
	
	$CppInfo = $PrevCppInfo;
	return $Buf;
}

### read instance definition #################################################
# syntax:
#	instance <module name> [#(<params>)] <instance name> <module file> (
#		<port>	<wire>	<attr>
#		a(\d+)	aa[$1]			// バス結束例
#		b		bb$n			// バス展開例
#	);
#
#	アトリビュート: <修飾子><ポートタイプ>
#	  修飾子:
#		M		Multiple drive 警告を抑制する
#		B		bit width weakly defined 警告を抑制する
#		U		tmpl isn't used 警告を抑制する
#	  ポートタイプ:
#		NP		reg/wire 宣言しない
#		NC		Wire 接続しない
#		W		ポートタイプを強制的に wire にする
#		I		ポートタイプを強制的に input にする
#		O		ポートタイプを強制的に output にする
#		IO		ポートタイプを強制的に inout にする
#		*D		無視
#
#		$l1 $u1	大文字・小文字変換

sub DefineInst{
	local $_;
	my( $Scpp ) = @_;
	
	my(
		$Port,
		$Wire,
		$WireBus,
		$Attr,
		
		$InOut,
		$Type,
		$BitWidthWire,
	);
	
	my $SkelList = [];
	
	my $LineNo = $.;
	
	# 引数取得
	if( !defined( $Scpp->{ arg }) || $#{ $Scpp->{ arg }} < 2 ){
		Error( 'invalid argument ($ScppInstance)' );
		return;
	}
	
	print( "DefineInst:" . join( ", ", @{ $Scpp->{ arg }} ) . "\n" ) if( $Debug >= 3 );
	
	# get module name, module inst name, module file
	my $SubModuleName = $Scpp->{ arg }[ 0 ];
	my $SubModuleInst = $Scpp->{ arg }[ 1 ];
	my $ModuleFile = ExpandMacro( $Scpp->{ arg }[ 2 ], $EX_STR );
	
	my $Buf = "$SubModuleInst = new $SubModuleName( \"$SubModuleName\" );\n";
	
	$ModuleFile =~ s/^"(.*)"$/$1/;
	$ModuleFile = $FileInfo->{ DispFile } if( $ModuleFile eq "." );
	
	# read port->wire tmpl list
	ReadSkelList( $SkelList, $Scpp->{ arg });
	
	# get sub module's port list
	my $ModuleIO = GetModuleIO( $SubModuleName, $ModuleFile );
	
	# input/output 文 1 行ごとの処理
	
	foreach $_ ( @$ModuleIO ){
		
		( $InOut, $Type, $Port ) = split( /\t/, $_ );
		next if( $InOut !~ /^sc_(?:in|out|inout)$/ );
		
		( $Wire, $Attr ) = ConvPort2Wire( $SkelList, $Port, $Type, $InOut );
		
		if( !( $Attr & $ATTR_NC )){
			next if( $Attr & $ATTR_IGNORE );
			
			# hoge(\d) --> hoge[$1] 対策
			
			$WireBus = $Wire;
			if( $WireBus  =~ /(.*)\[(\d+(?::\d+)?)\]$/ ){
				# ★要修正
				
				$WireBus		= $1;
				$BitWidthWire	= $2;
				$BitWidthWire	= $BitWidthWire =~ /^\d+$/ ? "$BitWidthWire:$BitWidthWire" : $BitWidthWire;
				
				# instance の tmpl 定義で
				#  hoge  hoge[1] などのように wire 側に bit 指定が
				# ついたとき wire の実際のサイズがわからないため
				# ATTR_WEAK_W 属性をつける
				$Attr |= $ATTR_WEAK_W;
			}else{
				$BitWidthWire	= $Type;
				
				# BusSize が [BIT_DMEMADR-1:0] などのように不明の場合
				# そのときは $ATTR_WEAK_W 属性をつける
				# ★要修正
				if( $Type ne '' && $Type !~ /^\d+:\d+$/ ){
					$Attr |= $ATTR_WEAK_W;
				}
			}
			
			# wire list に登録
			
			if( $Wire !~ /^\d/ ){
				$Attr |= ( $InOut eq "sc_in" )		? $ATTR_REF		:
						 ( $InOut eq "sc_out" )		? $ATTR_FIX		:
												 	  $ATTR_BYDIR	;
				
				RegisterWire(
					$WireBus,
					$BitWidthWire,
					$Attr,
					$ModuleName
				);
			}elsif( $Wire =~ /^\d+$/ ){
				# 数字だけが指定された場合，bit幅表記をつける
				# ★要修正
				#$Wire = sprintf( "%d'd$Wire", GetBusWidth2( $Type ));
			}
		}
		
		$Buf .= $SubModuleInst . "->$Port( $Wire );\n";
	}
	
	# インデント
	
	$Scpp->{ line } =~ /^(\s*)/;
	my $indent = $1;
	
	$Buf =~ s/\n/\n$indent/g;
	$Buf =~ s/[^\n]+$//;
	$ModuleInfo->{ $ModuleName }{ instance }{ $SubModuleInst } = "$indent$Buf";
	
	# SkelList 未使用警告
	
	WarnUnusedSkelList( $SkelList, $SubModuleInst, $LineNo );
}

### search module & get IO definition ########################################

sub GetModuleIO{
	local $_;
	my( $ModuleName, $ModuleFile, $ModuleFileDisp ) = @_;
	$ModuleFileDisp = $ModuleFile if( !defined( $ModuleFileDisp ));
	
	printf( "GetModuleIO: $ModuleName, $ModuleFile, $ModuleFileDisp\n" ) if( $Debug >= 2 );
	
	PushFileInfo( $ModuleFile );
	
	my $PrevCppInfo = $CppInfo;
	my $fp = CPreprocessor( $ModuleFile );
	if( !$fp ){
		PopFileInfo(); return;
	}
	
	# module の先頭を探す
	my $bFound = 0;
	my $Buf = '';
	
	while( $_ = ReadLine()){
		if( !$bFound ){
			# module をまだ見つけていない
			if( /\bSC_MODULE\s*\(\s*$ModuleName\s*\)\s*(.*)/ ){
				$bFound = 1;
				$Buf = $1;
			}
		}else{
			# module の途中
			$Buf .= ExpandMacro( $_, $EX_RMSTR | $EX_RMCOMMENT );
			if( $Buf =~ /^\s*($OpenCloseBlock)/ ){
				$Buf = $1;
				$bFound = 2;
				last;
			}
		}
	}
	
	PopFileInfo();
	$CppInfo = $PrevCppInfo;
	
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
		next if( !/^\s*(sc_(?:in|in_clk|out|inout|signal))\b\s*(.*)/ );
		
		# in / out / signal の判定
		# sc_in_clk は， io=sc_in type=_clk にする
		
		( $io, $_ ) = ( $1, $2 );
		
		# 型取得
		if( $io eq 'sc_in_clk' ){
			$io		= 'sc_in';
			$Type	= '_clk';
		}elsif( /\s*($OpenCloseType)\s*(.*)/ ){
			( $Type, $_ ) = ( $1, $2 );
			$Type =~ s/\s+//g;
		}else{
			$Type = '';
		}
		
		# 変数名取得
		foreach $Name ( split( /,/, $_ )){
			$Name =~ s/\s+//g;
			push( @$Port, "$io	$Type	$Name" );
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
		$i
	);
	
	for( $i = 3; $i <= $#{ $List }; ++$i ){
		$_ = $List->[ $i ];
		
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
			( $AttrLetter =~ /d$/  ) ? $ATTR_IGNORE	: 0;
		
		push( @$SkelList, {
			port => $Port,
			wire => $Wire,
			attr => $Attr,
		} );
		
		print( "skel: '$_' /$Port/$Wire/$Attr\n" ) if( $Debug >= 3 );
	}
}

### tmpl list 未使用警告 #####################################################

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
		# Hit した
		if( $Port =~ /^$Skel->{ port }$/ ){
			# port tmpl 使用された
			$Skel->{ attr } |= $ATTR_USED;
			
			$SkelPort = $Skel->{ port };
			$SkelWire = $Skel->{ wire };
			$Attr	  = $Skel->{ attr };
			
			# NC ならリストを作らない ★要修正
			
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

### wire の登録 ##############################################################

sub RegisterWire{
	
	my( $Name, $Type, $Attr, $ModuleName ) = @_;
	my( $Wire );
	
	if( defined( $Wire = $ModuleInfo->{ $ModuleName }{ WireListHash }{ $Name } )){
		# すでに登録済み
		
		# ATTR_WEAK_W が絡む場合の BitWidth を更新する
		if(
			!( $Attr			& $ATTR_WEAK_W ) &&
			( $Wire->{ attr }	& $ATTR_WEAK_W )
		){
			# List が Weak で，新しいのが Hard なので代入
			$Wire->{ type } = $Type;
			
			# list の ATTR_WEAK_W 属性を消す
			$Wire->{ attr } &= ~$ATTR_WEAK_W;
			
		}elsif(
			( $Attr				& $ATTR_WEAK_W ) &&
			( $Wire->{ attr }	& $ATTR_WEAK_W )
		){
			# List，新しいの ともに Weak なので，型不明
			
			$Wire->{ type } = $Type = "<UNKNOWN>";
			
		}elsif(
			!( $Attr			& $ATTR_WEAK_W ) &&
			!( $Wire->{ attr }	& $ATTR_WEAK_W ) &&
			$Wire->{ type } =~ /^\d+:\d+$/ && $Type =~ /^\d+:\d+$/
		){
			# 両方 Hard なので，サイズが違っていれば size mismatch 警告
			
			if( $Wire->{ type } ne $Type ){
				Warning( "unmatch port type ( $ModuleName.$Name $Type != $Wire->{ type } )" );
			}
		}
		
		# 両方 inout 型なら，登録するほうを REF に変更
		
		if( $Wire->{ attr } & $Attr & $ATTR_INOUT ){
			$Attr |= $ATTR_REF;
		}
		
		# multiple driver 警告
		
		if(
			( $Wire->{ attr } & $Attr & $ATTR_FIX ) &&
			!( $Attr & $ATTR_MD )
		){
			Warning( "multiple driver ($Name)" );
		}
		
		$Wire->{ attr } |= ( $Attr & ~$ATTR_WEAK_W );
		print( "RegWire: upd: $ModuleName.$Name\n" ) if( $Debug >= 3 );
		
	}else{
		# 新規登録
		
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
# $Mode eq "d" で in/out/wire 宣言文モード

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
	
	$WireCntUnresolved = 0;
	$WireCntAdded	   = 0;
	
	foreach $ModuleName ( sort keys %$ModuleInfo ){
		
		undef @WireListBuf;
		
		foreach $Wire ( @{ $ModuleInfo->{ $ModuleName }{ WireList }} ){
			
			$Attr = $Wire->{ attr };
			$Type = QueryWireType( $Wire, "" );
			
			$Type =	$Type eq "in"		? "I" :
					$Type eq "out"		? "O" :
					$Type eq "inout"	? "B" :
					$Type eq "signal"	? "W" :
										  "-" ;
			
			++$WireCntUnresolved if( !( $Attr & ( $ATTR_BYDIR | $ATTR_FIX | $ATTR_REF )));
			if( !( $Attr & $ATTR_DEF ) && ( $Type =~ /[IOCB]/ )){
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
			
			print( $fp "*** $ModuleName wire list ***\n" );
			print( $fp @WireListBuf );
		}
	}
	close( $fp ) if( $Debug );
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
