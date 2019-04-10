package constants;

use strict;
use utf8;
binmode(STDOUT, ":utf8"); 


use vars qw($VERSION);
$VERSION             = 80;       # バージョン番号(100倍した数字 : 100 -> ver1.00)

use vars qw($CONFIG_FILE $CONFIG_DIR $POINTER_FILE $ADMIN_PASSWORD_FILE $BLACKLIST_FILE);
$CONFIG_FILE         = './setting/bbs.conf.json';  # コンフィグファイル
$POINTER_FILE        = 'pointer';                  # ポインタファイル
$ADMIN_PASSWORD_FILE = 'adminpasswd';              # 管理者パスワードファイル
$BLACKLIST_FILE      = 'blacklist';                # スレッド立てすぎブラックリストファイル

use vars qw($BBS_TOP $READ_CGI $WRITE_CGI $ADMIN_CGI);
$BBS_TOP   = 'bbs.html';    # トップページHTML
$READ_CGI  = 'read.cgi';    # スレッド表示CGI
$WRITE_CGI = 'write.cgi';   # 発言投稿CGI
$ADMIN_CGI = 'admin.cgi';   # 管理者機能CGI

use vars qw($PUBLIC_DIR_PERMISSION $SECRET_DIR_PERMISSION $PUBLIC_FILE_PERMISSION $SECRET_FILE_PERMISSION);
$PUBLIC_DIR_PERMISSION  = 0700;
$SECRET_DIR_PERMISSION  = 0700;
$PUBLIC_FILE_PERMISSION = 0600;
$SECRET_FILE_PERMISSION = 0600;


use vars qw($EXT_LOG $EXT_PUBLIC $EXT_SECRET $EXT_GZIP $EXT_TEMP $EXT_LOCK $EXT_HTML);
$EXT_LOG      = 'log';     # 発言ログであることをあらわす拡張子
$EXT_PUBLIC   = 'pub';     # 公開されていることをあらわす拡張子
$EXT_SECRET   = 'sec';     # 非公開であることをあらわす拡張子
$EXT_GZIP     = 'gz';      # gzip圧縮の拡張子
$EXT_TEMP     = $$;        # 一時ファイル拡張子
$EXT_LOCK     = 'lock';    # ロックファイル拡張子
$EXT_HTML     = 'html';    # 過去ログHTMLの拡張子


use vars qw($CREATE $REVISE $DELETE $POST);
$CREATE = 'create';  # 新規スレッド作成
$REVISE = 'revise';  # 発言修正
$DELETE = 'delete';  # 発言削除
$POST   = 'post';    # 発言投稿

use vars qw($EMAIL $WEB);
$EMAIL       = 'EMAIL';
$WEB         = 'WEB';

use vars qw($THREADLIST_INFO $ADMIN_INFO);
$THREADLIST_INFO = './setting/bbs.html.templete';
$ADMIN_INFO      = './setting/admin.html.templete';

use vars qw($PROGRAMMER_WEBPAGE $MANUAL_PAGE $ADMIN_PAGE $JAVA_SCRIPT $STYLESHEET);
$PROGRAMMER_WEBPAGE = 'http://www.sarinaga.com/';  # スクリプト作者のページ
$MANUAL_PAGE  = 'index.html';                      # インデックスページ(内容はマニュアル)
$ADMIN_PAGE   = 'admin.html';                      # 管理者用ページ
$JAVA_SCRIPT  = 'bbs.js';                          # javascript
$STYLESHEET   = 'bbs.css';                         # スタイルシート




1;


