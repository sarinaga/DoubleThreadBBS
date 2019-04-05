use strict;
package constants;

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
$PUBLIC_DIR_PERMISSION  = 0755;
$SECRET_DIR_PERMISSION  = 0700;
$PUBLIC_FILE_PERMISSION = 0644;
$SECRET_FILE_PERMISSION = 0600;


use vars qw($EXT_LOG $EXT_PUBLIC $EXT_SECRET $EXT_GZIP $EXT_TEMP $EXT_LOCK $EXT_HTML);
$EXT_LOG      = 'log';     # 発言ログであることをあらわす拡張子
$EXT_PUBLIC   = 'pub';     # 公開されていることをあらわす拡張子
$EXT_SECRET   = 'sec';     # 非公開であることをあらわす拡張子
$EXT_GZIP     = 'gz';      # gzip圧縮の拡張子
$EXT_TEMP     = $$;        # 一時ファイル拡張子
$EXT_LOCK     = 'lock';    # ロックファイル拡張子
$EXT_HTML     = 'html';    # 過去ログHTMLの拡張子



1;


