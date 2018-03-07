# 機能

- instance 結線の自動化
- ポート・中間 wire 自動追加
- signal trace 記述の自動出力
- センシティビティリストの分離抑制

# 方針

- 出力がそのまま入力できるようにしたほうが良い?
- 既存の cpp からなるべく省力で def.cpp 化したい

# ディレクティブ

- #if SCPP_... #endif
 - #endif が cpp で消える

- SCPP_...{ }
 - scpp をかけないつもりのファイルでは syntax error になる
 - scpp.h を include するルールにして空になるようマクロ定義，はあり?

- コメント //#... { ... //#}
 - scpp をかけないつもりのファイルでは syntax error になる

# 課題
- <...> を include しない仕組みのためには，include を自前 parse する必要あり→結局自前 cpp を実装しないといけないのか?
