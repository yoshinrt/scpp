# scpp.pl - SystemC preprocessor

## 概要

SystemC は，ハードウェア表現に特化した言語ではなく，C++ ＋ライブラリで実現されているため，記述容易性において様々な問題があります．

scpp は，そのような SystemC の記述性改善を目的としたプリプロセッサです．以下の機能を持っています．

- モジュール接続の自動化：
モジュール間の信号接続を，ルールに従って自動的に結線します．Emacs の Verilog モードの `AutoConnect` と同等の機能です．
また必要な中間信号を自動的に生成します．

- `SC_METHOD()`, `SC_THREAD()`, `SC_CTHREAD()` 記述分離の抑制：
SystemC では，これらの記述は `SC_CTOR()` に記述しなければならず，関数本体から分離して記述しなければなりませんが，scpp では，関数本体の直前に記述することができます．

- `sc_trace()` 記述の自動生成：
有償ツールなどを使わない限り，SystemC で信号ダンプしたい場合は，ダンプしたい信号は階層名を含めて手動で指定する必要がありますが，それを自動化します．

- メンバイニシャライザによる信号名設定の自動生成：
`sc_trace()` で，波形ダンプに正確な信号名を表示するためには，ポート・信号に信号名を設定しなければなりませんが，これを自動化します．

- `SC_METHOD()` のセンシティビティリスト自動生成: Verilog-HDL では `always@( * )` 表記でセンシティビティリストを省略できますが，scpp でこれを実現します．

- テストベンチ記述の省力化：DUT をインスタンス化するスタブ記述作成を省力化します．

C++ ソースコードに埋め込まれたディレクティブ (`$ScppInstance` 等) を置換することで，上記のことを実現します．それ以外の記述は一切変更しません．

## とりあえず動かしてみる

	git clone https://github.com/yoshinrt/scpp.git
	cd sample
	make SYSTEMC=path_to_systemc_root

で，サンプルの SystemC モジュールの sim を行うことができます．また，\*.scpp.cpp / \*.scpp.h を元に，\*.cpp / \*.h が生成されます．

scpp による変更前後のファイルを比較 (コミット [e2de8eb](https://github.com/yoshinrt/scpp/commit/e2de8ebf21cb2da5fb7b808ad69ad70537179cf8)，もしくは `diff sample/SimpleDma.scpp.h sample/SimpleDma.h`) することで，どのような記述が自動生成されたかを確認できます．

## コマンドライン

```
scpp.pl [-I<include path>] [-D<name>[=<definition>]] [-o <output file>]
    [-v] [--clean] <input file>
```

- `-I<include path>`: インクルードファイルのサーチパスの末尾に `<include path>` を追加します．
- `-D<name>[=<definition>]`: `<name>` をマクロとして `<definition>` に定義します．`<definition>` が省略された場合，1 に定義されます．
- `-o <output file>`: 出力ファイル名を指定します．省略時は `<input file>` が `<input file>.bak` にリネームされた後，`<input file>` に上書きされます．
- `-v`: 自動認識したポートやシグナル等の情報を `<src_file>.list` に出力します．
- `--clean`: scpp.pl が自動生成した記述を削除します．
- `<input file>`: 入力ファイル名を指定します．

## ディレクティブの記述

C++ ソースコードにディレクティブを記述するには，以下のいずれかの形式を使用します．`$ScppSomeDirective` は，具体的には `$ScppInstance` 等を記述します．使用できるディレクティブについては [scpp ディレクティブ 一覧](#scpp-%E3%83%87%E3%82%A3%E3%83%AC%E3%82%AF%E3%83%86%E3%82%A3%E3%83%96-%E4%B8%80%E8%A6%A7) を参照してください．

- 1 行，Begin ～ End なし

```c++
// $ScppSomeDirective( <ディレクティブ引数> ... )
```

- 1 行，Begin ～ End あり

```c++
// $ScppSomeDirective( <ディレクティブ引数> ... ) Begin
    <C++ code> ...
// $ScppEnd
```

- 複数行，Begin ～ End なし

```c++
/* $ScppSomeDirective(
    <ディレクティブ引数> ...
) */
```

- 複数行，Begin ～ End あり

```c++
/* $ScppSomeDirective(
    <ディレクティブ引数> ...
) Begin */
    <C++ code> ...
// $ScppEnd
```

ディレクティブは，C++ コメントとして記述します．

ディレクティブ引数がない，または省略する場合は，( ) ごと省略することができます．

ディレクティブ引数等を複数行に分けて記述する場合は，`/* ... */` 形式のコメントを使用する必要があります．`//` 形式のコメントで複数行に分けることはできません．

scpp は，ディレクティブにより自動生成した C++ コードを `Begin ... $ScppEnd` の間に出力します．scpp 処理前に `Begin ... $ScppEnd` 間に記述されていたコードは一旦削除されます．また `Begin ... $ScppEnd` が記述されていない場合，scpp により自動的に追加されます．

## 内蔵プリプロセッサについての注意点

scpp は **C プリプロセッサ** (cpp) を内蔵しており，scpp は C++ ソースコードを解析時 (例えば，モジュールのポート解析) は，内蔵 cpp を通してから処理されます．したがって以下の制限があります．

- `systemc.h` をインクルード時は `<...>` を使用して `#include <systemc.h>` と記述してください．spcc は，`<...>` を使用した `include` は無視することで，`SC_MODULE` 等のマクロが展開されることを抑制しています．
- 同様に，システムインクルードヘッダ (`stdio.h` 等) は `<...>` で記述してください．
- `#ifdef` 等でソースコードが切り替えられている場合，scpp 実行時の define 状況で処理されます．scpp 処理後に define 状態が変更された場合，scpp により自動生成されたコードと一致しない場合があります．
- 上記のような制限があるため，パラメタライズ設計を行うときは，極力 define による定義ではなく，C++ テンプレート等の cpp マクロ展開されない手法で実施することを推奨します．

## 既知の課題

既知の課題については [こちら](https://github.com/yoshinrt/scpp/issues) を参照してください．

まともな C++ パーザは実装してませんので，ちょっと凝った記述をするだけでまともに動作しません．

# scpp ディレクティブ 一覧
- [$ScppAutoMember](#scppautomember)
- [$ScppAutoMemberSim](#scppautomembersim)
- [$ScppCthread](#scppcthread)
- [$ScppFunction](#scppfunction)
- [$ScppInitializer](#scppinitializer)
- [$ScppInstance](#scppinstance)
- [$ScppMethod](#scppmethod)
- [$ScppSensitive](#scppsensitive)
- [$ScppSigTrace](#scppsigtrace)
- [$ScppThread](#scppthread)

------------------------------------------------------------------------------
# $ScppAutoMember
## 概要

必要な信号，モジュールへのポインタ変数，プロトタイプ宣言を出力します．

## 書式

`$ScppAutoMember`

引数はありません．

## 解説

[$ScppInstance](#scppinstance) で自動生成された信号 及び `SC_MODULE` へのポインタ変数，
[$ScppMethod](#scppmethod)，
[$ScppThread](#scppthread)，
[$ScppCthread](#scppthread)，
[$ScppFunction](#scppfunction)
 が記述されたメンバ関数のプロトタイプ宣言を出力します．

詳細はそれぞれの解説を参照してください．

## 記述例

```c++
// $ScppAutoMember
```

出力結果

```c++
// $ScppAutoMember Begin
sc_signal<sc_uint<32> > SrcAddr;
sc_signal<sc_uint<32> > DstAddr;
sc_signal<sc_uint<32> > XferCnt;
sc_signal<bool> Run;
sc_signal<bool> Done;
sc_signal<bool> NceCh[CH_NUM];
sc_signal<sc_uint<32> > RegRDataCh[CH_NUM];
sc_signal<sc_uint<32> > SrcAddrCh[CH_NUM];
sc_signal<sc_uint<32> > DstAddrCh[CH_NUM];
sc_signal<sc_uint<32> > XferCntCh[CH_NUM];
sc_signal<bool> RunCh[CH_NUM];
sc_signal<bool> DoneCh[CH_NUM];
SimpleDmaCore *u_SimpleDmaCore;
SimpleDmaReg *u_SimpleDmaReg[CH_NUM];
void AddrDecorder( void );
void ArbiterSelector( void );
void RDataSelector( void );
// $ScppEnd
```

------------------------------------------------------------------------------
# $ScppAutoMemberSim
## 概要

シミュレーションテストベンチ用に，必要な信号，モジュールへのポインタ変数，プロトタイプ宣言を出力します．

## 書式

`$ScppAutoMemberSim`

引数はありません．

## 解説

[$ScppAutoMember](#scppautomember) と下記を除き同一の機能です．詳細については [$ScppAutoMember](#scppautomember) を参照してください．

[$ScppAutoMember](#scppautomember) との違いは，以下のとおりです．

- `sc_in / sc_out / sc_inout` の代わりに `sc_signal` が生成されます．
- `sc_fifo_in / sc_fifo_out / sc_fifo_inout` の代わりに `sc_fifo` が生成されます．

`$ScppAutoMemberSim` はテストベンチ記述において，DUT のポートと接続するための `sc_signal` 記述を自動的に生成することを意図しています．

## 記述例

```c++
// $ScppAutoMemberSim
```

出力結果

```c++
// $ScppAutoMemberSim Begin
sc_signal<bool> nrst;
sc_signal<sc_uint<32> > RegAddr;
sc_signal<sc_uint<32> > RegWData;
sc_signal<bool> RegNce;
sc_signal<bool> RegWrite;
sc_signal<sc_uint<32> > RegRData;
sc_signal<sc_uint<32> > SramAddr;
sc_signal<sc_uint<32> > SramWData;
sc_signal<bool> SramNce;
sc_signal<bool> SramWrite;
sc_signal<sc_uint<32> > SramRData;
SimpleDma<8> *SimpleDma0;
// $ScppEnd
```

------------------------------------------------------------------------------
# $ScppInitializer
## 概要

信号の name を設定するメンバイニシャライザ記述を出力します．

## 書式

`$ScppInitializer[( <char> )]`

- `char`: 出力する区切り文字等を文字列で指定します．
	- 文字列に `:` が含まれる場合，初期化リストの先頭に `:` を出力します．ただし，初期化リストが何もないときは，何も出力されません．
	- 文字列に `,` が含まれる場合，初期化リストの最後に `,` を出力します．ただし，初期化リストが何もないときは，何も出力されません．
	- `":,"` のように，両方指定することが可能です．

## 解説

コンストラクタに指定する，信号の name 初期化のためのメンバイニシャライザ記述を生成します．

SystemC で信号をダンプ (`sc_trace()`) し，ダンプファイルで信号名を正しく表示するためには，メンバイニシャライザで信号名を指定する必要がありますが，`$ScppInitializer` はそれを自動化します．

認識したすべての `sc_in_clk / sc_in / sc_out / sc_inout / sc_signal` のメンバイニシャライザ記述を生成します．

ただし，それらの信号が配列の場合，メンバイニシャライザ記述は生成されません (C++ 仕様による制限)．

## 記述例

```c++
SC_CTOR( SimpleDma ) :
    // $ScppInitializer( ":" )
{
```

出力結果

```c++
SC_CTOR( SimpleDma )
    // $ScppInitializer Begin
    : clk( "clk" ),
    nrst( "nrst" ),
    RegAddr( "RegAddr" ),
    RegWData( "RegWData" ),
    RegNce( "RegNce" ),
    RegWrite( "RegWrite" ),
    RegRData( "RegRData" ),
    SramAddr( "SramAddr" ),
    SramWData( "SramWData" ),
    SramNce( "SramNce" ),
    SramWrite( "SramWrite" ),
    SramRData( "SramRData" ),
    SrcAddr( "SrcAddr" ),
    DstAddr( "DstAddr" ),
    XferCnt( "XferCnt" ),
    Run( "Run" ),
    Done( "Done" )
    // $ScppEnd
{
```

------------------------------------------------------------------------------
# $ScppCthread
## 概要

`SC_CTHREAD()` 記述を，関数本体の直前に記述することを可能にします．

## 書式

`$ScppCthread( <clock>[, <reset>, <attr>])`

- `clock`: クロックイベントを指定します
- `reset`: リセット信号を指定します
- `attr`: リセットの属性を，以下の組み合わせで文字列で指定します
	- `"a"`: `async_reset_signal_is()` を生成します
	- `"s"`: `reset_signal_is()` を生成します
	- `"p"`: リセット極性を true に設定します
	- `"n"`: リセット極性を false に設定します

`reset`, `attr` を省略時は，`async_reset_signal_is()`，`reset_signal_is()` 記述は生成されません．

## 解説

`SC_CTHREAD()` 記述を，関数本体の直前に記述することを可能にします．

`SC_CTHREAD()` は `SC_CTOR()` 内に記述しなければならず，通常は動作を記述した関数本体から離れていますが，これは可読性に問題があります．

`$ScppCthread` を関数本体の直前に記述することで，`$ScppSensitive` の位置に `SC_CTHREAD()` 記述を生成します．

また，`$ScppAutoMember` の位置に，その関数のプロトタイプ宣言記述を生成します．

## 記述例

```c++
// $ScppCthread( clk.pos(), nrst, "an" )
void SimpleDmaReg::RegWriteThread( void ){
```

出力結果 (`$ScppSensitive`)

```c++
// $ScppSensitive( "SimpleDmaReg.cpp" ) Begin
SC_CTHREAD( RegWriteThread, clk.pos() );
async_reset_signal_is( nrst, false );

// $ScppEnd
```

出力結果 (`$ScppAutoMember`)

```c++
// $ScppAutoMember Begin
void RegWriteThread( void );
// $ScppEnd
```

------------------------------------------------------------------------------
# $ScppFunction
## 概要

メンバ関数のプロトタイプ宣言をヘッダファイルに生成します．

## 書式

`$ScppFunction`

引数はありません．

## 解説

`$ScppFunction` を関数本体の直前に記述することで，`$ScppAutoMember` の位置に，その関数のプロトタイプ宣言記述を生成します．

このディレクティブは直接 SystemC とは関係ありませんが，[$ScppMethod](#scppmethod) や [$ScppCthread](#scppthread) 等と同じような感覚で，ヘッダファイルにプロトタイプ宣言記述を生成することができます．

## 記述例

```c++
// $ScppFunction
sc_uint<32> Decoder::GaloaLog( sc_uint<32> idx ){
    ...
}

// $ScppFunction
void Decoder::Compute(
    sc_uint<32>     *DataBuf,
    sc_uint<32>&    DataSize
){
    ...
}
```

出力結果 (`$ScppAutoMember`)

```c++
// $ScppAutoMember Begin
sc_uint<32> GaloaLog( sc_uint<32> idx );
void Compute(
    sc_uint<32>     *DataBuf,
    sc_uint<32>&    DataSize
);
// $ScppEnd
```

------------------------------------------------------------------------------
# $ScppInstance
## 概要

SystemC モジュールをインスタンスし，自動的に結線します．また必要な信号を自動生成します．

## 書式

`$ScppInstance( <submodule>, <instance>, <file> [, <regexp> ...])`

- `submodule`: インスタンス化するサブモジュール名を指定します．
- `instance`: インスタンス化するサブモジュールのインスタンス名を指定します．
- `file`: サブモジュール名が記述されたファイルを指定します．ファイル名に "." を指定すると，`$ScppInstance` が記述されたファイル自身を指定します．
- `regexp`: ポート⇔信号 結線ルールを指定します．

## 解説

SystemC モジュールをインスタンスし，自動的に結線します．また必要な信号を自動生成します．

現在のところ，自動接続可能なポートは `sc_(in|out|inout)` `sc_(in|out|inout)_clk` `sc_fifo_(in|out|inout)` に限られます．

### サブモジュールポート→信号名 への変換

`regexp` に指定されたルールに従い，サブモジュールのポートをモジュールの信号名に変換します．`regexp` の書式は以下のとおりです．

`"/port/signal/option"`

`port` には perl 正規表現を使用できます．`regexp` が複数記述されている場合，ルールの一番目から順番に `port` にマッチするかどうかが照合され，最初にマッチしたルールが採用されます．記述容易性のため，`port` には先頭に '^'，末尾に '$' が自動的に付加されます．

- 例: `clka` `clkb` もマッチさせるためには，`clk.*` と記述する必要があります．

`signal` は，そのポートに接続する信号名を指定します．`port` でグルーピング `(...)` を使用した場合，`$1` 等の後方参照が使用できます．

- 例: `"/clk(.*)/CLK$1/"` … `clka` ポートが `CLKa` 信号に接続されます．

すべてのルールにマッチしなかった場合，ポート名と同名の信号に接続されます．

`option` には次の文字列をいくつか指定します．`option` は省略可能です．

- `I`: 接続された信号を強制的に `sc_in` にします
- `O`: 接続された信号を強制的に `sc_out` にします
- `IO`: 接続された信号を強制的に `sc_inout` にします
- `W`: 接続された信号を強制的に `sc_signal` にします
- `NC`: この出力ポートが浮きポートであることを宣言します．実際にはダミーの sc_signal が生成され，それに接続されます．
- `d`: このルールにマッチしたポートは，自動結線の対象から外されます．

`port` は省略可能です．省略された場合，`.*` と記述したとみなされます．

`signal` は省略可能です．省略された場合，`port` と同名の信号に接続されます．

正規表現の区切り記号である `/` は別の記号でも記述可能であり，`regexp` の先頭の文字を区切り文字と認識します．例えば，"/hoge.*/fuga/" と記述した場合，`*/` の部分で複数行コメントの終わりと認識されてしまうため，正常にパースできません．この場合，`"@hoge.*@fuga@"` 等，別の記号を使用する必要があります．

### 信号の生成

`$ScppInstance` が記述されたモジュールのすべての `$ScppInstance` を処理し終えた後，次のルールに従って信号が生成され，`$SccAutoMember` の場所に出力します．

1. モジュール内に既に `sc_in` 等の信号の宣言が存在する場合: 信号は生成されません
1. `option` で `I`, `O` 等の指定がある場合: その指定に従って信号が生成されます
1. `sc_in`, `sc_out` 両方に接続されている場合 (例えば，submodule_a の sc_in と submodule_b の sc_out に接続されている場合): `sc_signal` が生成されます
1. `sc_in` のみに接続されている場合: `sc_in` が生成されます
1. `sc_out` のみに接続されている場合: `sc_out` が生成されます

サブモジュールのポートが多次元配列の場合，同次元・同サイズの信号に接続されます．つまり，`u_Inst.port[ n ] -> signal[ n ]` のように接続されます．

### インスタンス配列の生成

`instance` には配列添字を指定することができ，この場合，インスタンス配列を生成します．下記の例では，8 個の Module モジュールがインスタンス化されます．

例: `$ScppInstance( Module, u_Inst[8], ... )`

またこのとき，結線ルールの `signal` の末尾に `[]` を指定することが出来ます．この場合，信号の配列が生成され，`u_Inst[ n ].port -> signal[ n ]` に接続されます．さらに port が多次元配列の場合，`u_Inst[ n ].port[ m ] -> signal[ n ][ m ]` のように接続されます．

## 記述例

```c++
/* $ScppInstance(
    SimpleDmaReg, u_SimpleDmaReg[ CH_NUM ], "SimpleDmaReg.h",
    "/clk|nrst//",
    "/(Addr|WData|Write)/Reg$1/",
    "/(RData)/Reg$1Ch[]/W",
    "//$1Ch[]/W",
) */
```

出力結果 (`$ScppInstance`)

```c++
/* $ScppInstance(
    SimpleDmaReg, u_SimpleDmaReg[ CH_NUM ], "SimpleDmaReg.h",
    "/clk|nrst//",
    "/(Addr|WData|Write)/Reg$1/",
    "/(RData)/Reg$1Ch[]/W",
    "//$1Ch[]/W",
) Begin */
for( int _i_0 = 0; _i_0 < CH_NUM; ++_i_0 ){
    u_SimpleDmaReg[_i_0] = new SimpleDmaReg(( std::string( "u_SimpleDmaReg(" ) + std::to_string(_i_0) + ")" ).c_str());
    u_SimpleDmaReg[_i_0]->clk( clk );
    u_SimpleDmaReg[_i_0]->nrst( nrst );
    u_SimpleDmaReg[_i_0]->Addr( RegAddr );
    u_SimpleDmaReg[_i_0]->WData( RegWData );
    u_SimpleDmaReg[_i_0]->Nce( NceCh[_i_0] );
    u_SimpleDmaReg[_i_0]->Write( RegWrite );
    u_SimpleDmaReg[_i_0]->RData( RegRDataCh[_i_0] );
    u_SimpleDmaReg[_i_0]->SrcAddr( SrcAddrCh[_i_0] );
    u_SimpleDmaReg[_i_0]->DstAddr( DstAddrCh[_i_0] );
    u_SimpleDmaReg[_i_0]->XferCnt( XferCntCh[_i_0] );
    u_SimpleDmaReg[_i_0]->Run( RunCh[_i_0] );
    u_SimpleDmaReg[_i_0]->Done( DoneCh[_i_0] );
}
// $ScppEnd
```

出力結果 (`$ScppAutoMember`)

```c++
// $ScppAutoMember Begin
SimpleDmaReg *u_SimpleDmaReg[CH_NUM];
// $ScppEnd
```

-------------------------------------------------------------------------------
# $ScppMethod
## 概要

`SC_METHOD()` 記述を，関数本体の直前に記述することを可能にします．

## 書式

`$ScppMethod[( code )]`

- `code`: センシティビティリストを表現する C++ コードを記述します

## 解説

`SC_METHOD()` 記述を，関数本体の直前に記述することを可能にします．

`SC_METHOD()` は `SC_CTOR()` 内に記述しなければならず，通常は動作を記述した関数本体から離れていますが，これは可読性に問題があります．

`$ScppMethod` を関数本体の直前に記述することで，`$ScppSensitive` の位置に `SC_METHOD()` 記述を生成します．

また，`$ScppAutoMember` の位置に，その関数のプロトタイプ宣言記述を生成します．

引数省略時は，その関数内で `.read()` されている信号をすべて使用して，センシティビティリストを自動的に生成します．

## 記述例

```c++
// $ScppMethod
void SimpleDma::AddrDecorder( void ){
    // (...省略...)

/* $ScppMethod(
for( int i = 0; i < CH_NUM; ++i ){
    sensitive << DstAddrCh[i] << RunCh[i] << SrcAddrCh[i] << XferCntCh[i];
}
sensitive << Done;
)*/
void SimpleDma::ArbiterSelector( void ){
```

出力結果 (`$ScppSensitive`)

```c++
// $ScppSensitive( "." ) Begin
SC_METHOD( AddrDecorder );
sensitive << RegAddr << RegNce;

SC_METHOD( ArbiterSelector );
for( int i = 0; i < CH_NUM; ++i ){
    sensitive << DstAddrCh[i] << RunCh[i] << SrcAddrCh[i] << XferCntCh[i];
}
sensitive << Done;

// $ScppEnd
```

出力結果 (`$ScppAutoMember`)

```c++
// $ScppAutoMember Begin
void AddrDecorder( void );
void ArbiterSelector( void );
// $ScppEnd
```

-----------------------------------------------------------------------------
# $ScppSensitive
## 概要

[$ScppMethod](#scppmethod)，[$ScppThread](#scppthread)，[$ScppCthread](#scppcthread) で記述されたセンシティビティリストを出力します．

## 書式

`$ScppSensitive( <file> [, <file> ...])`

- `file`: `$ScppMethod, $ScppThread, $ScppCthread` が記述されたファイルを指定します．ファイル名に "." を指定すると，`$ScppSensitive` が記述されたファイル自身を指定します．

## 解説

[$ScppMethod](#scppmethod)，[$ScppThread](#scppthread)，[$ScppCthread](#scppcthread) で記述されたセンシティビティリストを出力します．

`SC_METHOD() SC_TREAD() SC_CTHREAD()` は `SC_CTOR()` 内に記述しなければならず，通常は動作を記述した関数本体から離れていますが，これは可読性に問題があります．

`$ScppSensitive` を `SC_CTOR()` 内に記述することで，指定された file から [$ScppMethod](#scppmethod)，[$ScppThread](#scppthread)，[$ScppCthread](#scppcthread) を検索し，センシティビティリスト記述を `$ScppSensitive` の位置に生成します．

## 記述例

```c++
// $ScppSensitive( "." )
```

出力結果

```c++
// $ScppSensitive( "." ) Begin
SC_METHOD( AddrDecorder );
sensitive << RegAddr << RegNce;

SC_METHOD( ArbiterSelector );
for( int i = 0; i < CH_NUM; ++i ){
    sensitive << DstAddrCh[i] << RunCh[i] << SrcAddrCh[i] << XferCntCh[i];
}
sensitive << Done;

SC_METHOD( RDataSelector );
for( int i = 0; i < CH_NUM; ++i ) sensitive << RegRDataCh[i];

// $ScppEnd
```

-------------------------------------------------------------------------------
# $ScppThread
## 概要

`SC_THREAD()` 記述を，関数本体の直前に記述することを可能にします．

## 書式

`$ScppThread( code )`

- `code`: センシティビティリストを表現する C++ コードを記述します

## 解説

`SC_THREAD()` 記述を，関数本体の直前に記述することを可能にします．

`SC_THREAD()` は `SC_CTOR()` 内に記述しなければならず，通常は動作を記述した関数本体から離れていますが，これは可読性に問題があります．

`$ScppThread` を関数本体の直前に記述することで，`$ScppSensitive` の位置に `SC_THREAD()` 記述を生成します．

また，`$ScppAutoMember` の位置に，その関数のプロトタイプ宣言記述を生成します．

## 記述例

```c++
// $ScppThread( sensitive << clk.pos())
void SimpleDma::ArbiterSelector( void ){
```

出力結果 (`$ScppSensitive`)

```c++
// $ScppSensitive( "." ) Begin
SC_THREAD( ArbiterSelector );
sensitive << clk.pos();

// $ScppEnd
```

出力結果 (`$ScppAutoMember`)

```c++
// $ScppAutoMember Begin
void ArbiterSelector( void );
// $ScppEnd
```

-----------------------------------------------------------------------------
# $ScppSigTrace
## 概要

そのモジュール内の信号の `sc_trace()` 記述を生成します．

## 書式

`$ScppSigTrace[( <regexp> ... )]`

- `regexp`: トレース対象，または除外する信号のルール (正規表現) を指定します．引数が省略された場合，モジュール内のすべての信号がトレースされます．

## 解説

そのモジュール内の信号の `sc_trace()` 記述を生成します．ただし SystemC の制限により，`sc_fifo` はトレースできません．

グローバル変数として `sc_trace_file *ScppTraceFile` が定義されていることを前提としています．またこのモジュールがインスタンス化される前に `ScppTraceFile` は `sc_create_vcd_trace_file()` されていなければなりません．

`#ifdef VCD_WAVE` していますので，VCD 出力するためには `VCD_WAVE` が define されている必要があります．

### ルールの記述

`regexp` に指定されたルールに従い，トレース対象または除外する信号が決定されます．`regexp` の書式は以下のとおりです．

`"/signal/option"`

`signal` には perl 正規表現を使用できます．`regexp` が複数記述されている場合，ルールの一番目から順番に `signal` にマッチするかどうかが照合され，最初にマッチしたルールが採用されます．記述容易性のため，`signal` には先頭に '^'，末尾に '$' が自動的に付加されます．

- 例: `clka` `clkb` もマッチさせるためには，`clk.*` と記述する必要があります．

すべてのルールにマッチしなかった信号は，トレース対象と判定されます．

`option` には次の文字列をいくつか指定します．`option` は省略可能です．

- `S`: このルールは，スカラ型の信号にのみ適用されます．
- `A`: このルールは，配列型の信号にのみ適用されます．
- `N`: このルールにマッチした信号は，トレース対象から除外されます．このオプションが指定されなかったルールにマッチした信号は，トレース対象になります．

`signal` は省略可能です．省略された場合，`.*` と記述したとみなされます．

正規表現の区切り記号である `/` は別の記号でも記述可能であり，`regexp` の先頭の文字を区切り文字と認識します．例えば，"/hoge.*/" と記述した場合，`*/` の部分で複数行コメントの終わりと認識されてしまうため，正常にパースできません．この場合，`"@hoge.*@"` 等，別の記号を使用する必要があります．

## 記述例

`sc_main()` の記述

```c++
ifdef VCD_WAVE
sc_trace_file *ScppTraceFile;
endif

int sc_main( int argc, char **argv ){
    
ifdef VCD_WAVE
    ScppTraceFile = sc_create_vcd_trace_file( "simple_dma" );
    ScppTraceFile->set_time_unit( 1.0, SC_NS );
endif

    SimpleDma *u_SimpleDma = new SimpleDma( "u_SimpleDma" );
```

個々のモジュールの記述

```c++
ifdef VCD_WAVE
extern sc_trace_file *ScppTraceFile;
endif

SC_MODULE( SimpleDma ){
    // ... (省略)...
    /* $ScppSigTrace(
        "/DataBuf/N"
    ) */
```

出力結果

```cpp
// $ScppSigTrace Begin
ifdef VCD_WAVE
sc_trace( ScppTraceFile, clk, std::string( this->name()) + ".clk" );
sc_trace( ScppTraceFile, nrst, std::string( this->name()) + ".nrst" );
sc_trace( ScppTraceFile, RegAddr, std::string( this->name()) + ".RegAddr" );
sc_trace( ScppTraceFile, RegWData, std::string( this->name()) + ".RegWData" );
sc_trace( ScppTraceFile, RegNce, std::string( this->name()) + ".RegNce" );
sc_trace( ScppTraceFile, RegWrite, std::string( this->name()) + ".RegWrite" );
sc_trace( ScppTraceFile, RegRData, std::string( this->name()) + ".RegRData" );
sc_trace( ScppTraceFile, SramAddr, std::string( this->name()) + ".SramAddr" );
sc_trace( ScppTraceFile, SramWData, std::string( this->name()) + ".SramWData" );
sc_trace( ScppTraceFile, SramNce, std::string( this->name()) + ".SramNce" );
sc_trace( ScppTraceFile, SramWrite, std::string( this->name()) + ".SramWrite" );
sc_trace( ScppTraceFile, SramRData, std::string( this->name()) + ".SramRData" );
sc_trace( ScppTraceFile, SrcAddr, std::string( this->name()) + ".SrcAddr" );
sc_trace( ScppTraceFile, DstAddr, std::string( this->name()) + ".DstAddr" );
sc_trace( ScppTraceFile, XferCnt, std::string( this->name()) + ".XferCnt" );
sc_trace( ScppTraceFile, Run, std::string( this->name()) + ".Run" );
sc_trace( ScppTraceFile, Done, std::string( this->name()) + ".Done" );
endif // VCD_WAVE
// $ScppEnd
```
