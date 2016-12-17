# 
#
# 何でだかわからないのですが、漢字コードの識別に失敗するので
# 適当に冒頭部分に駄文を書かせていただきます。ご了承を。
#
# あ、↑の文を書いたらうまく判別できた。よかった、よかった。
#
#
#
# マルチスレッド掲示板 - write.pl
#
#                                          2002.10.23 さゆりん先生
#
#
#
use strict;
package writecgi;

use vars qw($CREATE $REVISE $DELETE $POST);
$CREATE = 'create';  # 新規スレッド作成
$REVISE = 'revise';  # 発言修正
$DELETE = 'delete';  # 発言削除
$POST   = 'post';    # 発言投稿

use vars qw($EMAIL $WEB $PASS_LENGTH_MIN $PASS_LENGTH_MAX);
$EMAIL       = 'EMAIL';
$WEB         = 'WEB';
$PASS_LENGTH_MIN = 5;
$PASS_LENGTH_MAX = 20;  # この部分は空文化している

use vars qw($THREADLIST_INFO $ADMIN_INFO);
$THREADLIST_INFO = 'threadlist.info';
$ADMIN_INFO      = 'admin.info';


##########################################################################
#                              テスト用領域                              #
##########################################################################


1;
