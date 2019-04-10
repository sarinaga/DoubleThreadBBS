#
#
# マルチスレッド掲示板 - ログ表示データ作成
#
#                                          2002.10.23 さゆりん先生
#
package html;
use strict;
use utf8;
use Cwd 'getcwd';
use Data::Dumper;

require './std.pl';
require './file.pl';
require './constants.pl';

# bbs.conf.json設定値(外部からこのグローバル変数に値をセットすること)
use vars qw($CONF);


use vars qw($TRIP_SEPARETE  $TREE_SPACE  $TREE_BRANCH  $TREE_BRANCH_END  $TREE_NODE);
$TRIP_SEPARETE   = '◆';  # 名前/トリップ区切り記号
$TREE_SPACE      = '　';  # ツリー表示用記号1
$TREE_BRANCH     = '┃';  # ツリー表示用記号2
$TREE_BRANCH_END = '┗';  # ツリー表示用記号3
$TREE_NODE       = '┣';  # ツリー表示用記号4
#$TREE_SPACE      = '　';  # ツリー表示用記号1
#$TREE_BRANCH     = '│';  # ツリー表示用記号2
#$TREE_BRANCH_END = '└';  # ツリー表示用記号3
#$TREE_NODE       = '├';  # ツリー表示用記号4


#
# 発言表示モードを表わす識別
#
use vars qw($COMPLETE $NO_REVISE $ATONE $RES $REV $TOMATO $TITLE $ADMIN
            $MESSAGE $TREE $IGNORE_KILL $HTML $FINAL $CONST);
$COMPLETE    = 0B0000000000000001;  #「新規投稿」ができない状態（発言数オーバー）
$NO_REVISE   = 0B0000000000000010;  #「発言修正」ができない状態（容量オーバー）

$ATONE       = 0B0000000000000100;  # １発言単体表示モードでの発言出力
$RES         = 0B0000000000001000;  # レス発言投稿フォーム用発言出力
$REV         = 0B0000000000010000;  # 発言修正フォーム用発言出力

$TOMATO      = 0B0000000000100000;  # 強制トマト表示

$TITLE       = 0B1000000000000000;  # 通常表示モードでタイトルを表示する
$MESSAGE     = 0B0100000000000000;  # 通常表示モードで発言を表示する
$TREE        = 0B0010000000000000;  # コメントリンクツリー形式で表示する

$IGNORE_KILL = 0B0001000000000000;  # （管理用）強制表示（キルマーク無視、ID、IPアドレスが常に表示される）
$ADMIN       = 0B0001000000000000;  # （管理用）上と同じ
$HTML        = 0B0000100000000000;  # （管理用）HTML用出力

$FINAL       = $COMPLETE | $NO_REVISE;  # 一切の変更ができない状態である
$CONST       = $FINAL;                  # 同上


use vars qw($PASS_MESSAGE $PASS_REINPUT $TRIP_MES $POST $CREATE $REVISE);
$PASS_MESSAGE = '発言を削除、訂正するのに必要. [0-9A-Za-z]で%d文字以上.';
$PASS_REINPUT = '発言を書き込んだときのパスワードを入力.';
$TRIP_MES = '固有IDを生成する. [0-9A-Za-z]で0文字以上.';
$POST   = '投稿する';
$CREATE = 'スレッド作成';
$REVISE = '発言訂正';

###########################################################################
#                          http response headerを生成                     #
###########################################################################
sub http_response_header{

	print << "RES";
Content-Type: text/html; charset=UTF-8
Content-Language: ja
Content-Style-Type: text/css
Content-Script-Type: text/javascript
Pragma: no-cache
Cache-Control: no-cache

RES
	return;

}


###########################################################################
#                           番号順で発言データを出力                      #
###########################################################################
sub multi{
	local(*FOUT) = shift; # 出力先ファイルハンドル
	my $log      = shift; # [参照]ログ
	my $param    = shift; # [参照]出力用パラメータ

	my $st       = $$param{'st'};
	my $en       = $$param{'en'};

	print FOUT "<dl class='message'>\n\n";
	for(my $i=$st;$i<=$en;$i++){
		mes_one(*FOUT, $i, $log, $param);
	}
	print FOUT "</dl>\n\n";

}


###########################################################################
#                       コメントツリー順で発言データを出力                #
###########################################################################
sub comment{
	local(*FOUT) = shift; # 出力先ファイルハンドル
	my $log      = shift; # [参照]ログ
	my $param    = shift; # [参照]出力用パラメータ

	# 発言をツリー順に並べる
	my @nums = search_thread($log, $$param{'st'}, $$param{'en'});
	foreach my $num(@nums){
		($num, undef, undef) = split(/:/, $num, 3);
	}

	print FOUT "<dl class='message'>\n\n";
	foreach my $num(@nums){
		mes_one(*FOUT, $num, $log, $param);
	}
	print FOUT "</dl>\n\n";

}


#
# スレッド発言番号
#
sub search_thread{
	my $log   = shift; # [参照]ログ
	my $st    = shift; # 探索する範囲（始）
	my $en    = shift; # 探索する範囲（終）
	my $max   = @$log-1;

	# ツリー作成用データ＆格納用
	my $space      = 'S';
	my $branch_end = 'E';
	my $branch     = 'B';
	my $node       = 'N';

	my @t_no;    # 発言番号
	my @t_tree;  # ツリー構造
	my @t_deep;  # ツリー深さ

	# 探索開始
	for(my $i=$st;$i<=$en;$i++){

		# レス発言のときはすでに選択されていると考える
		if (defined($$log[$i]{'RES'})){
			next if ($$log[$i]{'RES'}>=$st);
		}

		# 根を記憶
		push(@t_no, $i);
		push(@t_deep, 0);
		push(@t_tree, '');

		# 枝を記憶するのに必要なデータ領域
		my @stack;
		my $now=$i+1;
		my $point=$i;

		# 枝の探索（二重ループに注意）
		for(;;){

			my $j;
			for($j=$now;$j<=$max;$j++){
				next unless(defined($$log[$j]{'RES'}));
				next unless($$log[$j]{'RES'}==$point);

				# 該当発言番号を記憶（枝）
				my $deep=@stack+1;
				push(@t_no, $j);
				push(@t_deep, $deep);
				push(@t_tree, std::spacer(std::math_min($deep-1, 10), $space) . $branch_end);

				# 上に向かって線を引く
				for(my $k=@t_tree-2;$k>=0;--$k){
					last if ($t_deep[$k] < $deep);
					if ($t_deep[$k] == $deep){ substr($t_tree[$k], $deep-1, 1) = $node; }
					else { substr($t_tree[$k], $deep-1, 1) = $branch }
				}

				# 枝の分岐を記憶
				push(@stack, $point);
				$point=$j;
				$now=$j+1;
				last;
			}

			# 枝の探索が発言最後まで行われた場合は記憶した枝の分岐まで戻る
			if ($j>$max){
				last if (@stack==0);
				$now=$point+1;
				$point=pop(@stack);
			}
		}
	}

	# ツリーデータを全角化
	foreach my $tree(@t_tree){
		$tree =~s/$space/$TREE_SPACE/g;
		$tree =~s/$branch_end/$TREE_BRANCH_END/g;
		$tree =~s/$branch/$TREE_BRANCH/g;
		$tree =~s/$node/$TREE_NODE/g;
	}

	# データを結合して返す
	my @thread;
	for(my $i=0;$i<scalar @t_no;++$i){
		push(@thread, join(':' , ($t_no[$i], $t_deep[$i], $t_tree[$i]) ));
	}
	return @thread;

}



#
# 発言を１つ出力
#
sub mes_one{
	local(*FOUT) = shift; # 出力先ファイルハンドル
	my $no       = shift; # 表示させる発言番号
	my $log      = shift; # [参照]ログデータ
	my $param    = shift; # [参照]発言表示パラメータ

	# パラメータ抽出
	my $st   = $$param{'st'};
	my $mode = $$param{'mode'};

	# ログデータから必要な情報を抽出（スレッド情報）
	my $post  = $$log[0]{'POST'};
	my $size  = $$log[0]{'SIZE'};
	my $t_no  = $$log[0]{'THREAD_NO'};

	return 0 if($no < 0 or $post <= $no);


	# ログデータから必要な情報を抽出（発言情報）
	my %dat = %{$$log[$no]};

	my @correct_time;
	@correct_time = @{$dat{'CORRECT_TIME'}} if (defined($dat{'CORRECT_TIME'}));

	# 発言番号～タイトル～ユーザ名～IPアドレス／ユーザID～時間～レス先を表示
	print FOUT "<dt id='s$no' class='header'>\n";
	message_header(*FOUT, $no, $log, $param);
	print FOUT "<br>\n";

	# 単体表示～レスをつける～発言修正の各リンクを表示
	my $kill = 0;
	if (!($mode & $ADMIN)){
		$kill = defined($dat{'DELETE_TIME'});
	}
	my $ctrl = 0;
	unless($mode & $ADMIN or $mode & $HTML ){
		$ctrl = !defined($dat{'DELETE_TIME'});
	}
	if ($ctrl){
		print FOUT "<span class='ctrl'>";
		unless(($mode & $ATONE) !=0){
			print FOUT "<a href='./$constants::READ_CGI?no=$t_no;at=$no'>単発言表示</a>　";
		}
		unless(($mode & $COMPLETE) !=0 or ($mode & $RES) !=0){
			print FOUT "<a href='./$constants::READ_CGI?no=$t_no;res=$no'>レスをつける</a>　";
		}
		unless(($mode & $REV) !=0){
			print FOUT "<a href='./$constants::READ_CGI?no=$t_no;rev=$no'>発言修正</a>";
		}
		print FOUT "</span><br>\n";
	}
	print FOUT "</dt>\n\n";

	# ログ本体を表示
	if (!$kill){
		my $body = body($dat{'BODY'});
		print FOUT "<dd class='body'>\n$body\n</dd>\n\n";
	}else{
		print FOUT "\n";
	}

	# IPアドレスを表示
	if ($$log[$no]{'TOMATO'} or ($mode & $TOMATO) !=0 or ($mode & $ADMIN) !=0 ){
		print FOUT "<dd class='tomato'>\n";
		for(my $i=0;$i<@{$$log[$no]{'IP_HOST'}};++$i){
			print FOUT "$$log[$no]{'IP_HOST'}[$i], $$log[$no]{'IP_ADDR'}[$i], $$log[$no]{'USER_AGENT'}[$i]<br>\n";
		}
		print FOUT "</dd>\n";
	}

	# 発言修正、発言削除日時を表示
	if (@correct_time > 0 or defined($dat{'DELETE_TIME'})){
		print FOUT "<dd class='info'>\n";
		foreach my $c_time(@correct_time){
			print FOUT 'この発言は' . std::time_format($c_time) . "に修正されています。<br>\n";
		}
		if (defined($dat{'DELETE_TIME'})){
			print FOUT 'この発言は' . std::time_format($dat{'DELETE_TIME'}) . 'に';
			print FOUT "削除人「$dat{'DELETE_ADMIN'}」によって" if (defined($dat{'DELETE_ADMIN'}));
			print FOUT "削除されています。<br>\n";
		}
		print FOUT "</dd>\n\n";
	}

	# 単発言表示終了
	print FOUT "\n";
	return;

}

#
# 発言のヘッダを出力する
#
# 発言番号、発言タイトル、名前、トリップ、ID
# 発言時間、レス先
#
sub message_header{
	local(*FOUT) = shift;  # 出力先
	my $target   = shift;  # 発言させる表示番号
	my $log      = shift;  # 発言ログ全部
	my $param    = shift;  # 出力パラメータ

	my $mode = $$param{'mode'};
	my $res  = $$log[$target]{'RES'};
	my $kill = (defined($$log[$target]{'DELETE_TIME'}) and !($mode & $ADMIN) );

	title(*FOUT, $target, $log, $param);

	print FOUT "<br>\n";
	print FOUT scalar std::time_format($$log[$target]{'POST_TIME'});
	if (defined($res)){
		print FOUT '　[';
		if($mode & $ADMIN){
			print FOUT "${res}番";
		}elsif ($$param{'st'} > $res){
			print FOUT "<a href='./$constants::READ_CGI?no=$$param{'no'};at=$res'>${res}番</a>";
		}else{
			print FOUT "<a href='#s$res'>${res}番</a>";
		}
		print FOUT 'へのコメント]';
	}

}


#
# 本文部分の装飾：改行を<br>に、行頭引用符に属性を付け、
# 連続空白を&nbsp;に変換
#
sub body{
	my $body=shift;
	$body="\n$body";
	$body=~s/\n(\|.*)/\n<q class="quote-pipe">$1<\/q>/g;
	$body=~s/\n(%.*)/\n<q class="quote-percent">$1<\/q>/g;
	$body=~s/\n(&gt;.*)/\n<q class="quote-gt">$1<\/q>/g;
	$body=~s/\n(\#.*)/\n<q class="quote-sharp">$1<\/q>/g;
	$body=substr($body,1);
	$body=~s/\n/<br>\n/g;
	return std::trans_space($body);
}


###########################################################################
#                             番号順に発言タイトルを出力                  #
###########################################################################
sub list{
	local(*FOUT) = shift; # 出力先ファイルハンドル
	my $log      = shift; # [参照]ログ
	my $param    = shift; # [参照]出力用パラメータ

	my $no = $$log[0]{'THREAD_NO'};

	my $st = $$param{'st'};
	my $en = $$param{'en'};

	my $st_block = int($st/10);
	my $en_block = int($en/10);

	print FOUT "<div class='list'>\n\n";
	for(my $i=$st_block;$i<=$en_block;$i++){

		print FOUT "<table class='list'><tbody>\n\n";

		for(my $j= (std::math_max($st,$i*10));
		       $j<=(std::math_min($en,$i*10+9));
		       $j++){

			print FOUT '<tr>';
			list_header(*FOUT, $j, $log, $param);
			print FOUT "</tr>\n";
		}
		print FOUT "</tbody></table>\n\n";
		print FOUT "<hr>\n\n" if ($i<$en_block);
	}
	print FOUT "</div>\n\n";

}

#
# リスト表示を出力する
#
# 発言番号、発言タイトル、名前、トリップ、ID、IPアドレス、レス先
#
sub list_header{
	local(*FOUT) = shift;  # 出力先
	my $target = shift;    # 発言させる表示番号
	my $log = shift;       # 発言ログ全部
	my $param = shift;     # 出力パラメータ

	my $mode = $$param{'mode'};
	my $res  = $$log[$target]{'RES'};
	my $kill = (defined($$log[$target]{'DELETE_TIME'}) and !($mode & $IGNORE_KILL));

	# 発言タイトル出力
	my $title = $$log[$target]{'TITLE'};
	my $short_title = short_string($title, $CONF->{'general'}->{'titleLengthMax'});
	print FOUT "<td class='num'><tt>$target.</tt></td>";
	print FOUT ' <td class="title">';
	if ($kill){                                   # 発言が削除されている場合
		print FOUT '<em class="kill">';
		$short_title = $CONF->{'general'}->{'killed'}->{'name'};

	}elsif((($mode & $TITLE) != 0 and ($mode & $MESSAGE) == 0) or ($mode & $ATONE) != 0 ){
	                                              # タイトルだけを表示される場合と
	                                              # 上記、現在表示されている発言以外の場合
		print FOUT "<a href='./$constants::READ_CGI?$$log[0]{'THREAD_NO'};at=$target' class='sub' title='$title'>";

	}else{                                        # その他の場合
		print FOUT "<a href='#s$target' class='sub' title='$title'>";
	}
	print FOUT $short_title;
	if ($kill){  print FOUT "</em>"; }
	else{        print FOUT "</a>";   }
	print FOUT '</td> ';

	# 名前出力～トリップ
	print FOUT '<td class="name">';
	unless($kill){
		my $name = $$log[$target]{'USER_NAME'};
		my $short_name = short_string($name, $CONF->{'general'}->{'nameLengthMax'});

		print FOUT "<span title='$name'>$short_name</span>";
		if (defined($$log[$target]{'TRIP'})){
			print FOUT "<span class='trip'>$TRIP_SEPARETE$$log[$target]{'TRIP'}</span>";
		}
	}else{
		print FOUT $CONF->{'general'}->{'killed'}->{'name'};
	}
	print FOUT '</td>';


	# レスポンス先出力
	print FOUT ' <td class="response">';
	if (defined($res)){
		if ($$param{'st'} > $res){
			print FOUT "<a href='./$constants::READ_CGI?no=$$param{'no'};at=$res'>${res}番</a>";
		}else{
			print FOUT "<a href='#d$res'>${res}番</a>";
		}
		print FOUT 'へのコメント';
	}
	print FOUT '</td>';

	# ID出力
	if ($$log[$target]{'USER_ID'}){
		print FOUT ' <td class="id">';
		print FOUT "ID:$$log[$target]{'USER_ID'}" if (!$kill);
		print FOUT '</td>';
	}

}


###########################################################################
#                     コメントツリー順で発言タイトルを出力                #
###########################################################################
sub tree{
	local(*FOUT) = shift; # 出力先ファイルハンドル
	my $log      = shift; # [参照]ログ
	my $param    = shift; # [参照]出力用パラメータ

	my $max = @$log-1;
	my $st  = $$param{'st'};
	my $en  = $$param{'en'};

	# ツリーの根を探す(単体表示のとき)
	if (($$param{'mode'} & $ATONE) != 0){
		while(defined($$log[$st]{'RES'})){
			$st = $en = $$log[$st]{'RES'};
		}
	}

 	# 発言をツリー順に並べる
	my @nums = search_thread($log, $st, $en);

	# ツリー表示する
	print FOUT "<div class='tree'>\n\n";
	for(my $i=0;$i<@nums;++$i){

		my ($num, $spc, $tree) = split(/:/, $nums[$i], 3);
		print FOUT "<br>\n" if ($spc == 0 and $i > 0);
		print FOUT $tree;
		title(*FOUT, $num, $log, $param);
		print FOUT "<br>\n";
	}
	print FOUT "</div>\n\n";
}



#
# タイトル、名前、トリップ、ID（選択された場合のみ）を表示
#
sub title{
	local(*FOUT) = shift;  # 出力先ファイルハンドル
	my $num      = shift;  # 表示する発言番号
	my $log      = shift;  # [参照] ログ
	my $param    = shift;  # [参照] パラメータ
	my $id       = shift;  # IDを表示するか？

	my $no     = $$log[0]{'THREAD_NO'};
	my $name   = $$log[$num]{'USER_NAME'};
	my $trip   = $$log[$num]{'TRIP'};
	my $title  = $$log[$num]{'TITLE'};
	my $email  = $$log[$num]{'USER_EMAIL'};
	my $web    = $$log[$num]{'USER_WEBPAGE'};

	my $st     = $$param{'st'};
	my $mode   = $$param{'mode'};

	my $kill = 0;
	my $no_link = 0;


	# 状態調整
	if (!($mode & $ADMIN)){
		if (defined($$log[$num]{'DELETE_TIME'}) ){
			$no_link = 1;
			$kill    = 1;
			$name    = $CONF->{'general'}->{'killed'}->{'name'};
			$title   = $CONF->{'general'}->{'killed'}->{'title'};
			$trip    = undef;
			$email   = undef;
			$web     = undef;
		}
	}
	$no_link = 1 if (($mode & $ATONE) != 0 and $num==$st);
	$no_link = 1 if ($mode & $ADMIN);

	# ヘッダ部分出力
	print FOUT "<tt>$num.</tt>";
	if ($kill){   # 発言が削除されている場合

		print FOUT '<em class="kill">';

	}elsif($no_link){  # 自分自身へのリンクをしない場合

		print FOUT "<em class='now' title='$title'>";

	}elsif((($mode & $TITLE) != 0 and ($mode & $MESSAGE) == 0) or ($mode & $ATONE) != 0 ){
	                                            # タイトルだけを表示する場合と
	                                            # 上記、現在表示されている発言以外の場合
		print FOUT "<a href='./$constants::READ_CGI?no=$no;at=$num' class='sub' title='$title'>";

	}else{                                      # その他の場合
		print FOUT "<a href='#s$num' class='sub' title='$title'>";

	}

	my $short_title = short_string($title, $CONF->{'general'}->{'titleLengthMax'});
	$short_title = std::trans_space($short_title);
	print FOUT $short_title;

	if($no_link or $kill){
		print FOUT '</em>';
	}else{
		print FOUT '</a>';
	}

	my $short_name = std::trans_space(short_string($name, $CONF->{'general'}->{'nameLengthMax'}));
	print FOUT "／<span title='$name'>$short_name";
	print FOUT "<span class='trip'>$TRIP_SEPARETE$trip</span>" if(defined($trip));
	print FOUT '</span>';

	if((!$kill or ($mode & $IGNORE_KILL) !=0) and $$log[$num]{'USER_ID'}){
		print FOUT "　<span class='id'>ID:$$log[$num]{'USER_ID'}</span>　";
	}else{
		print FOUT '　';
	}

	# email、webページを表示する
	link_email(*FOUT, $email, $name) if ($email and !$kill);
	link_webpage(*FOUT, $web, $name) if ($web   and !$kill);

}


#
# 文字列（スレッド名、タイトル名、人名）を短くする
#
sub short_string{
	my $string = shift;
	my $length = shift;
	return $string if (length($string) <= $length);
	return substr($string, 0, $length) . '...';
}


###########################################################################
#                           スレッド一覧を出力する                        #
###########################################################################
sub thread_list{
	local(*FOUT) = shift;  # 出力先ファイルハンドル
	my $thread   = shift;  # スレッド情報[参照]
	my $dat      = shift;  # dat行きの情報も出力するかどうか/管理モード[admin.cgi用]

	# age順（降順）にソートする
	@$thread = sort { $$b{'AGE_TIME'} <=> $$a{'AGE_TIME'} } @$thread;

	# スレッド一覧を出力する～有効なスレッドがない場合
	print FOUT "<div class='thread-list'>\n\n";
	unless (@$thread > 0){
		print FOUT "<p>スレッドはまだ作られていないか、有効なスレッドがありません。</p>\n\n</div>\n\n";
		return;
	}

	# スレッド一覧を出力する（本データ）
	print FOUT "<table class='thread-list'><tbody>\n\n";
	foreach my $t(@$thread){

		next if ($$t{'DAT'});    # DAT行きデータの時は処理しない

		print FOUT "<tr><td class='no'>$$t{'THREAD_NO'}.</td><td class='thread'>";
		print FOUT "<a href='./$constants::READ_CGI?no=$$t{'THREAD_NO'};ls=$CONF->{'general'}->{'displayLast'};tree=1;sub=1' ";
		print FOUT "class='thread' title='最新$CONF->{'general'}->{'displayLast'}レスを表示'>";

		my $thread_name = $$t{'THREAD_TITLE'};
		my $thread_short = short_string($thread_name, $CONF->{'general'}->{'threadLengthMax'});

		print FOUT "<span title='$thread_name'>$thread_short</span></a>";
		print FOUT "($$t{'POST'})</td><td class='date'>" . std::time_format($$t{'AGE_TIME'}) . "</td>";
		print FOUT "<td class='all'><a href='./$constants::READ_CGI?no=$$t{'THREAD_NO'}' ";
		print FOUT "title='スレッド$$t{'THREAD_NO'}番、番号順'>全発言表示</a></td>";
		print FOUT "<td class='titleonly'><a href='./$constants::READ_CGI?no=$$t{'THREAD_NO'};sub=1;mes=0;tree=1' ";
		print FOUT "title='スレッド$$t{'THREAD_NO'}番、コメント順'>全題名表示</a></td></tr>\n";
	}
	print FOUT "\n</tbody></table>\n\n";
	print FOUT "</div>\n\n";

}



###########################################################################
#                                 emailリンク                             #
###########################################################################
sub link_email{
	local(*FOUT) = shift; # 出力先ファイルハンドル
	my $email    = shift; # emailアドレス
	my $name     = shift; # 名前

	$email = std::shredder("mailto:$email");
	print FOUT "<a href='$email' title='$name'>";
	if ($CONF->{'icon'}->{'email'}){
		print FOUT "<img src='$CONF->{'icon'}->{'email'}' alt='email'>";
	}else{
		print FOUT '<small>email</small>';
	}
	print FOUT '</a>　';
}



###########################################################################
#                                Webページリンク                          #
###########################################################################
sub link_webpage{
	local(*FOUT) = shift; # 出力先ファイルハンドル
	my $webpage  = shift; # webpage http
	my $name     = shift; # 名前

	$webpage = std::shredder($webpage);
	print FOUT "<a href='http://$webpage' title='$name'>";
	if ($CONF->{'icon'}->{'web'}){
		print FOUT "<img src='$CONF->{'icon'}->{'web'}' alt='webpage'>";
	}else{
		print FOUT '<small>webpage</small>';
	}
	print FOUT '</a>　';

}



###########################################################################
#                          スレッド一覧表示へのリンク                     #
###########################################################################
sub link_top{
	local(*FOUT) = shift; # 出力先ファイルハンドル
	print FOUT "<a href='./$constants::BBS_TOP'>スレッド一覧</a>　";
}



###########################################################################
#                            掲示板から抜けるリンク                       #
###########################################################################
sub link_exit{
	local(*FOUT) = shift; # 出力先ファイルハンドル
	print FOUT "<a href='$CONF->{'general'}->{'exitTo'}'>トップページ</a>　";
}



###########################################################################
#                             全発言表示へのリンク                        #
###########################################################################
sub link_all{
	local(*FOUT) = shift; # 出力先ファイルハンドル
	my $no       = shift; # スレッド番号
	print FOUT "<a href='./$constants::READ_CGI?no=$no' title='スレッド${no}番、番号順'>全発言表示</a>　";
}



###########################################################################
#                              全題名表示へのリンク                       #
###########################################################################
sub link_title{
	local(*FOUT) = shift; # 出力先ファイルハンドル
	my $no       = shift; # スレッド番号
	print FOUT "<a href='./$constants::READ_CGI?no=$no;sub=1;mes=0;tree=1' title='スレッド${no}番、コメント順'>全題名表示</a>　";
}



###########################################################################
#                             最新レス表示へのリンク                      #
###########################################################################
sub link_new{
	link_new100(@_);
}
sub link_new100{
	local(*FOUT) = shift; # 出力先ファイルハンドル
	my $no       = shift; # スレッド番号
	print FOUT "<a href='./$constants::READ_CGI?no=$no;ls=$CONF->{'general'}->{'displayLast'};sub=1;tree=1'>最新$CONF->{'general'}->{'displayLast'}レス表示</a>　";
}



###########################################################################
#                             管理者モードへのリンク                      #
###########################################################################
sub link_adminmode{
	local(*FOUT) = shift; # 出力先ファイルハンドル
	print FOUT "<a href='./$constants::ADMIN_PAGE'>管理モード</a>　";
}



###########################################################################
#                             管理者宛メールへのリンク                    #
###########################################################################
sub link_adminmail{
	local(*FOUT) = shift; # 出力先ファイルハンドル
	print FOUT "<a href='mailto:" . $CONF->{'general'}->{'adminMail'} . "'>管理者宛メール</a>　";
}



###########################################################################
#                      スレッド一覧表示、全発言表示、                     #
#                   全題名表示最新100レス表示、のセット                   #
###########################################################################
sub link_set{
	link_3set(@_);
}
sub link_3set{   # 互換のため（関数命名に大失敗）
	local(*FOUT) = shift; # 出力先ファイルハンドル
	my $no       = shift; # スレッド番号
	print FOUT '<div class="link">';
	link_top(*FOUT);
	link_all(*FOUT, $no);
	link_title(*FOUT, $no);
	link_new100(*FOUT, $no);
}


###########################################################################
#                スレッド一覧表示、全発言表示、全題名表示、               #
#              最新100レス表示、管理者宛メールのセット（閉じ）            #
###########################################################################
sub link_set_close{
	link_3set_close(@_);
}
sub link_3set_close{  # 互換のため（関数命名に大失敗）
	local(*FOUT) = shift; # 出力先ファイルハンドル
	my $no       = shift; # スレッド番号
	link_set(*FOUT, $no);
	link_adminmail(*FOUT);
	print FOUT "</div>\n\n";
}



###########################################################################
#                        パスワード入力文字列生成                         #
###########################################################################
sub pass_message{
	return sprintf($PASS_MESSAGE, $CONF->{'general'}->{'passwordLength'});
}



###########################################################################
#                          HTMLヘッダ部分を出力                           #
###########################################################################
sub header{
	local(*FOUT) = shift;  # 出力先
	my $title    = shift;  # ページタイトル
	my $base     = shift;  # <base>要素を利用するか？ [事実上未使用]
	my $cookie   = shift;  # cookie内容（ハッシュref）
	my $expires  = shift;  # cookie有効期限
	my $outhtml  = shift;  # html化の時のヘッダ出力？

	# DOCTYPE宣言を出力
	print FOUT << "HEADER";
<!DOCTYPE html>

<html>

<head>

HEADER

	# タイトル、base要素、スタイルシート、基本javascriptを出力
	print FOUT "<meta charset='f'>\n";
	print FOUT "<base href='$CONF->{'general'}->{'baseHttp'}'>\n" if ($base);
	print FOUT "<link rel='stylesheet' type='text/css' href='./$constants::STYLESHEET'>\n";
	print FOUT "<script type='text/javascript' src='./$constants::JAVA_SCRIPT'></script>\n" if(!$outhtml);

	# cookie設定javascriptを出力
	if ($cookie){
		print FOUT "<script type='text/javascript'>\n";
		foreach my $key(keys %$cookie){
			print FOUT "    setCookie('$key', '$$cookie{$key}', compute_expires($expires));\n";
		}
		print FOUT "</script>\n";
	}
	print FOUT "<title>$title - $CONF->{'general'}->{'bbsName'}</title>\n\n";

	# タイトル部分出力
	print FOUT << "TITLE";
</head>

<!--======================================================================-->

<body>

<h1 id='title'>$CONF->{'general'}->{'bbsName'}</h1>

TITLE

}



###########################################################################
#                             HTMLフッタ部分を出力                        #
###########################################################################
sub footer{
	local(*FOUT) = shift;  # 出力先

	# バージョン番号を計算
	my $ver=sprintf("%1.2f", $constants::VERSION / 100);

	# フッタ部分出力
	print FOUT '<div class="version" lang="en">';
	print FOUT "Double Thread BBS version $ver - programed by ";
	print FOUT "<a href='$constants::PROGRAMMER_WEBPAGE'>";
	print FOUT "SAYURIN-SENSEI</a></div>\n\n</body>\n\n</html>\n";
}



###########################################################################
#                              水平線のコメント                           #
###########################################################################
sub hr{
	local(*FOUT) = shift;  # 出力先
	print FOUT "<!--======================================================================-->\n\n";
}



###########################################################################
#                              送信フォーム各種                           #
###########################################################################

# 発言表示フォーム
sub form_read{
	local(*FOUT) = shift;
	my $no     = shift;  # スレッド番号
	my $last   = shift;  # 最後の発言番号
	my $target = shift;  # 単体表示番号
	my $kind   = shift;  # 単体発言をする理由

	my $span = $target ? 4 : 3;  # rowspanの数を調整する
	print FOUT << "FORM";
<h3 id='change-mode'>表示形態切り替え</h3>

<form method='get' action='./$constants::READ_CGI' class='read' id='read' name='read' onsubmit='return check_read_form(this, $last);'>
<table class="change-mode">

<tbody>

<!-- 番号等を指定して移動するフォーム部分 -->
<tr><td rowspan='$span'>
発言番号 <input type='hidden' name='no' value='$no'>
         <input type='text' name='st' size='5' value='0'>から
         <input type='text' name='en' size='5' value='$last'>まで
<br>

表示順序 <select name='tree' size='1'>
           <option value='1' selected='selected'>ツリー</option>
           <option value='0' >発言番号</option>
         </select>順
<br>

表示形態 <input type='checkbox' name='sub' value='1'>題名表示
         <input type='checkbox' name='mes' value='1' checked='checked'>発言表示

<br>
<input type='submit' value='決定'>
</td>

<!-- 簡易的リンク -->
FORM

	# 全発言表示へのリンク
	print FOUT '<td class="or">or</td> <td>';
	link_all(*FOUT, $no);
	print FOUT "</td></tr>\n";

	# 全題名表示へのリンク
	print FOUT '<tr><td class="or">or</td> <td>';
	link_title(*FOUT, $no);
	print FOUT "</td></tr>\n";

	# 最新100レス表示へのリンク
	print FOUT '<tr><td class="or">or</td> <td>';
	link_new100(*FOUT, $no);
	print FOUT "</td></tr>\n";

	# 単体発言表示へのリンク
	if ($target){
		print FOUT "<tr><td class='or'>or</td> <td>";
		print FOUT "<a href='./$constants::READ_CGI?no=$no;at=$target'>${kind}発言の単体表示</a></td></tr>\n";
	}

	print FOUT "\n</tbody>\n\n</table>\n\n</form>\n\n";

}




# 書き込みフォーム冒頭部分（以下すべて書き込み）
sub formparts_head{
	local(*FOUT) = shift;
	print FOUT << "HTML";
<form method='post' action='./$constants::WRITE_CGI' class='post' id='post' name='post' onsubmit='return check_write_form(this);'>

<table class="post">
<tbody>

HTML
}


# 新スレッド作成専用
sub formparts_createthread{
	local(*FOUT) = shift;
	print FOUT << "HTML";
<tr class="thread">
<th>スレッド名</th>
<td>
  <input type='text' name='thread' size='40' value=''>
</td>
</tr>

HTML
}


# 名前～ウェブページ
sub formparts_name{
	local(*FOUT) = shift;
	my ($user, $title, $body, $email, $webpage) = @_;

	#
	# 名前部分
	#
	print FOUT "<tr class='name'>\n<th>名前</th>\n<td>\n";
	print FOUT "  <input type='text' name='name' size='20' ";
	if (defined($user)){
		print FOUT "value='$user'>\n";

	}else{
		print FOUT ">\n";
		print FOUT << "HTML0";
  <script type='text/javascript'>
    document.post.name.value = getCookie("USER_NAME");
  </script>
HTML0
	}
	print FOUT "</td>\n</tr>\n\n";

	#
	# タイトル部分～webpage部分
	#
	print FOUT << "HTML1";
<tr class="title">
<th>タイトル</th>
<td>
  <input type='text' name='title' size='40' value='$title'>
</td>
</tr>

<tr class="body">
<th>本文</th>
HTML1
	print FOUT "<!--===========-->" if ($body);
	print FOUT "<td><textarea cols='60' rows='10' name='body'>";
	if ($body){
		print FOUT "\n$body\n</textarea></td>";
		print FOUT "<!--=========================================-->\n";

	}else{
		print FOUT "</textarea></td>\n";
	}
	print FOUT "</tr>\n\n";

	print FOUT "<tr class='email'>\n<th>email</th>\n<td>\n";
	print FOUT "  mailto:<input type='text' name='email' size='30' ";
	if (defined($email)){
		print FOUT "value='$email'>\n";
	}else{
		print FOUT ">\n";
		print FOUT << "HTML3";
  <script type='text/javascript'>
     document.post.email.value = getCookie("USER_EMAIL");
  </script>
HTML3
	}
	print FOUT "</td>\n</tr>\n\n";

	print FOUT "<tr class='webpage'>\n<th>webpage</th>\n<td>\n";
	print FOUT "  http://<input type='text' name='web' size='30' ";
	if (defined($webpage)){
		print FOUT "value='$webpage'>\n";

	}else{
		print FOUT ">\n";
		print FOUT << "HTML5";
  <script type='text/javascript'>
    document.post.web.value = getCookie("USER_WEBPAGE");
  </script>
HTML5
	}
	print FOUT "</td>\n</tr>\n\n";

}



# トリップ＆パスワード
sub formparts_password{
	local(*FOUT) = shift;
	my $trip     = shift;
	my $form_mes = shift;

	if ($trip){
		print FOUT << "TRIP";
<tr class="trip">
<th>トリップ</th>
<td>
  <input type='text' name='trip' size='10'>
  <small>$TRIP_MES</small>
  <script type='text/javascript'>
    document.post.trip.value = getCookie("TRIP");
  </script>
</td>
</tr>

TRIP
	}

	print FOUT << "PASS";
<tr class="pass">
<th>パスワード</th>
<td>
  <input type='password'
         name='pass'
         size='10'
         required='required'
         minlength='$CONF->{'general'}->{'passwordLength'}'>
  <small>$form_mes</small>
  <script type='text/javascript'>
    document.post.pass.value = getCookie("PASSWORD");
  </script>
</td>
</tr>

PASS

}

# cookie, age, tomato
sub formparts_age{
	local(*FOUT) = shift;
	my $agesage  = shift;
	my $tomato   = shift;

	print FOUT << "COOKIE";
<tr class='other'>
<th>その他</th>
<td>
  <input type='checkbox' name='cookie' value='1'> cookieを保存する.
  <script type='text/javascript'>
    var cookie = getCookie("COOKIE");
    if (cookie == 1)
        document.post.cookie.checked = true;
    else
        document.post.cookie.checked = false;
  </script>
COOKIE

	if ($agesage){
		print FOUT << "SAGE";

  <input type='checkbox' name='sage' value='1'> 発言をあげない.
  <script type='text/javascript'>
    var sage = getCookie("SAGE");
    if (sage == 1)
        document.post.sage.checked = true;
    else
        document.post.sage.checked = false;
  </script>
SAGE
	}

	if ($tomato){
		print FOUT << "TOMATO";

  <input type='checkbox' name='tomato' value='1'> IPアドレス強制表示.
  <script type='text/javascript'>
    var tomato = getCookie("TOMATO");
    if (tomato == 1)
        document.post.tomato.checked = true;
    else
        document.post.tomato.checked = false;
  </script>
TOMATO
	}

	print FOUT "</td>\n</tr>\n\n";

}


# 末尾部分（ボタン）
sub formparts_foot{
	local(*FOUT) = shift;
	my $post     = shift;  # 送信ボタンの文字
	my $mode     = shift;  # 投稿モード CREATE | REVISE | POST
	my $t_no     = shift;  # スレッド番号
	my $target   = shift;  # レス先／修正先

	print FOUT << "HTML0";
<tr class="post">
<th>フォーム送信</th>
<td>
  <input type='submit' value='$post' >
  <input type='reset' value='リセット'
         onclick='return reset_form();'
         onkeypress='return reset_form();' >
  <input type='hidden' name='mode' value='$mode'>
HTML0

	if($mode ne $constants::CREATE){
		print FOUT "  <input type='hidden' name='no' value='$t_no'>\n";
		if ($mode eq $constants::REVISE){
			print FOUT "  <input type='hidden' name='target' value='$target'>\n";
		}elsif($mode eq $constants::POST and defined($target)){
			print FOUT "  <input type='hidden' name='res' value='$target'>\n";
		}
	}
	print FOUT << "HTML1";
</td>
</tr>

</tbody>
</table>

</form>

HTML1
}


# データ削除フォーム
sub formparts_delete{
	my ($no, $target) = @_;
	print << "DEL";
<form method='post' action='./$constants::WRITE_CGI' id='d_post' name='d_post' onSubmit='return check_password(document.d_post.pass.value);'>
<p class="delete">
  <input type="hidden"   name="no" value="$no">
  <input type="hidden"   name="target" value="$target">
  <input type="hidden"   name="mode" value="$constants::DELETE">
  <input type='password' name='pass' size="10">
  <input type='submit'   size='8' value='発言削除'>
  <small>$PASS_REINPUT</small>
  <script type='text/javascript'>
    document.d_post.pass.value = getCookie("PASSWORD");
  </script>
</p>
</form>

</div>

DEL
}


###########################################################################
#                    スレッド情報からbbs.htmlを作成する                   #
###########################################################################
sub create_bbshtml{
	my $thread      = shift;   # スレッド情報[参照]


	# bbs.html をロックする
	my $bbs_html = "./$constants::BBS_TOP";
	return 0 unless (file::filelock($bbs_html));

	# bbs.htmlヘッダ作成
	my $tempfile = file::temp_name($bbs_html);
	return 0 unless(open(FOUT, ">$tempfile"));
	header(*FOUT, 'スレッド一覧表示');

	# bbs.html冒頭説明文出力
	my $info = '';
	open(FIN, $constants::THREADLIST_INFO) || die "テンプレートファイル'${constants::THREADLIST_INFO}'がオープンできなかった.";
	until(eof(FIN)){
		$info .= <FIN>;
	}

	print FOUT "<div class='info'>\n\n";
	print FOUT "$info\n";
	print FOUT "</div>\n\n";
	hr(*FOUT);

	# リンクバー出力
	print FOUT "<div class='link'>";
	print FOUT '<a href="#create-thread">新規スレッド作成</a>　';
	link_exit(*FOUT);
	link_adminmode(*FOUT);
	link_adminmail(*FOUT);
	print FOUT "</div>\n\n";
	hr(*FOUT);

	# スレッド一覧部分出力
	print FOUT "<div class='thread'>\n\n";
	print FOUT "<h3 id='thread'>スレッド一覧</h3>\n\n";
	thread_list(*FOUT, $thread);
	print FOUT "</div>\n\n";
	hr(*FOUT);

	# リンクバー
	print FOUT "<div class='link'>";
	link_exit(*FOUT);
	link_adminmode(*FOUT);
	link_adminmail(*FOUT);
	print FOUT "</div>\n\n";
	hr(*FOUT);

	# 新規スレッド作成フォーム作成
	print FOUT "<div class='create-thread'>\n\n";
	print FOUT "<h3 id='create-thread'>新規スレッド作成</h3>\n\n";
	formparts_head(*FOUT);
	formparts_createthread(*FOUT);
	formparts_name(*FOUT, undef, '', '', undef, undef);
	formparts_password(*FOUT, 1, pass_message() );
	formparts_age(*FOUT, 0, 1);
	formparts_foot(*FOUT, $html::CREATE, $constants::CREATE);
	print FOUT "</div>\n\n";

	# リンクバー
	print FOUT "<div class='link'>";
	link_exit(*FOUT);
	link_adminmode(*FOUT);
	link_adminmail(*FOUT);
	print FOUT "</div>\n\n";
	hr(*FOUT);

	# 末尾部分
	footer(*FOUT);
	close(FOUT);

	# テンポラリファイルから正式ファイルに変換
	return file::renew($bbs_html);
}


###########################################################################
#                      admin.html 管理ページを更新する                    #
###########################################################################
sub create_adminpage{

	# 情報整理
	my $version      = sprintf("%1.2f", $constants::VERSION / 100);
	my $bbs_top      = "./$constants::BBS_TOP";
	my $stylesheet   = "./$constants::STYLESHEET";
	my $admin_mail   = $CONF->{'general'}->{'adminMail'};
	my $programmer   = $constants::PROGRAMMER_WEBPAGE;

	# admin.infoの読み込み
	return 0 unless(open(FIN, $constants::ADMIN_INFO));
	my $info = '';
	until(eof(FIN)){
		$info .= <FIN>;
	}
	$info =~ s/(\$\w+)/$1/gee;

	# admin.htmlの書き出し
	my $admin_html = "./$constants::ADMIN_PAGE";
	return 0 unless (file::filelock($admin_html));
	my $tempfile = file::temp_name($admin_html);
	return 0 unless(open(FOUT, ">$tempfile"));
	print FOUT $info;
	close(FOUT);

	# テンポラリファイルから正式ファイルに変換
	return file::renew($admin_html);


}




###########################################################################
#                              試験用領域                                 #
###########################################################################





1;

