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

## とりあえず動かしてみる

	git clone https://github.com/yoshinrt/scpp.git
	cd sample
	make SYSTEMC=path_to_systemc_root

で，サンプルの SystemC モジュールの sim を行うことができます．また，\*.scpp.cpp / \*.scpp.h を元に，\*.cpp / \*.h が生成されます．

scpp による変更前後のファイルを比較 (コミット [e2de8eb](https://github.com/yoshinrt/scpp/commit/e2de8ebf21cb2da5fb7b808ad69ad70537179cf8)，もしくは `diff sample/SimpleDma.scpp.h sample/SimpleDma.h`) することで，どのような記述が自動生成されたかを確認できます．

より詳細な解説は [Wiki](https://github.com/yoshinrt/scpp/wiki) を参照してください．
