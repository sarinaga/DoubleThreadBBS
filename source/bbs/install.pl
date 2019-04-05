use strict;
use File::Path;
use Crypt::PasswdMD5;

require './configReader.pl';
require './connstants.pl';
require './bbsFile.pl';

use vars qw($CONF);
$CONF = configReader::readConfig();
$file::CONF = $CONF;

##########################################################################
#                   ファイル、ディレクトリの初期化                       #
##########################################################################
sub createDirectory{

	# ディレクトリを作る
	my %dirs = {
	  $CONF->{'log'}->{'public'} => $constants::PUBLIC_DIR_PERMISSION,
	  $CONF->{'log'}->{'secret'} => $constants::SECRET_DIR_PERMISSION,
 	  $CONF->{'log'}->{'html'}   => $constants::PUBLIC_DIR_PERMISSION,
	};

	foreach my $dir(keys %dirs){

		chop($dir);
		if (-e $dir){
			if (-d $dir){
				rmtree($dir);
			}else{
				unlink($dir);
			}
			print "ディレクトリまたはファイルで'${dir}'があったので削除します.\n";
		}

		if (-e $dir){
			die "ディレクトリまたはファイル'${dir}'を削除できませんでした. ";
		}

		unless (mkdir($dir, $dirs{$dir})){
			die "ディレクトリ'${dir}'を作成できませんでした. ";
		}

		print "ディレクトリ'${dir}'を作成しました.";
	}

}

##########################################################################
#                       ポインタファイルの作成                           #
##########################################################################
sub createPointer(){
	my $pointer_file = pointer_name();
	unless(open(FOUT, ">$pointer_file")){
		die "ポインタファイルを初期化できませんでした.";
	}
	print FOUT "0\n";
	close(FOUT);
	unless(chmod($constants::SECRET_FILE_PERMISSION, $pointer_file)){
		die "ポインタファイルにパーミッションが設定できませんでした.";
	}
}

##########################################################################
#                     ブラックリストファイルの作成                       #
##########################################################################
sub createBlacklist(){

	my $blacklist_file = blacklist_name();
	#system("touch $blacklist_file");
	unless(open(FOUT, ">$blacklist_file")){
		die "ブラックリストファイルを初期化できませんでした.";
	}
	close(FOUT);
	unless(chmod($constants::SECRET_FILE_PERMISSION, $blacklist_file)){
		die "ブラックリストファイルにパーミッションが設定できませんでした.";
	}
}

##########################################################################
#                   管理者パスワードファイルの作成                       #
##########################################################################
sub createAdminPassword(){
	my $password_file = adminpass_name();
	unless(open(FOUT, ">$password_file")){
		die "管理者パスワードファイルを初期化できませんでした.";
	}
	my $cpassword = apache_md5_crypt('admin', std::salt());
	print FOUT "admin:$cpassword";
	close(FOUT);
	unless(chmod($constants::SECRET_FILE_PERMISSION, $password_file)){
		die "管理者パスワードファイルにパーミッションが設定できませんでした.";
	}

}

###########################################################################
#                       bbs.htmlとadmin.htmlの作成                        #
###########################################################################
sub createPage{


	# bbs.htmlの作成
	my @thread = [];
	unless (file::create_bbshtml(\@thread)){
		die "bbs.htmlが作成できませんでした.";
	}

	# admin.htmlの作成
	unless (file::create_adminpage()){
		die "admin.htmlが作成できませんでした.";
	}

}

createDirectory();
createPointer();
createBlackList();
createAdminPassword();
createPage();

