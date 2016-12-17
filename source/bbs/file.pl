#
#
# �ޥ������åɷǼ��� - �ե����������ϴط�����
#
#                                          2002.10.23 ����������
#
#
package file;
use strict;

use lib '/home/sarinaga/lib/i386-freebsd';

use File::Copy;
use Digest::SHA1 qw(sha1 sha1_hex sha1_base64);

require './html.pl';    # create_bbshtml��
require './write.pl';   # create_bbshtml��

BEGIN{
	use vars qw($TIME_HIRES_OK);
	$TIME_HIRES_OK = 1;
	eval "use Time::HiRes qw(sleep);";
	$TIME_HIRES_OK = 0 if ($@);
}


use vars qw($CONFIG_FILE $CONFIG_DIR $POINTER_FILE $BLACKLIST_FILE $BBS_TOP_PAGE_FILE $PASSWORD_FILE);
$CONFIG_FILE         = 'bbs.conf';   # ����ե����ե�����
$CONFIG_DIR          = './';         # ����ե����ե����뤬�֤���Ƥ���ǥ��쥯�ȥ�
$POINTER_FILE        = 'pointer';    # �ݥ��󥿥ե�����
$BLACKLIST_FILE      = 'blacklist';  # ����������¤˰��ä����äƤ���IP���ɥ쥹��IP�ۥ��Ȥ��Ǽ
$BBS_TOP_PAGE_FILE   = 'bbs.html';   # �ȥåץڡ����ե�����/����åɰ���ɽ��
$PASSWORD_FILE       = 'passwd';     # �ѥ���ɥե�����


use vars qw($READ_SCRIPT $WRITE_SCRIPT $ADMIN_SCRIPT);
$READ_SCRIPT  = 'read.cgi';
$WRITE_SCRIPT = 'write.cgi';
$ADMIN_SCRIPT = 'admin.cgi';

use vars qw($PUBLIC_DIR_PERMISSION $SECRET_DIR_PERMISSION 
            $PUBLIC_FILE_PERMISSION $SECRET_FILE_PERMISSION);
$PUBLIC_DIR_PERMISSION  = 0755;
$SECRET_DIR_PERMISSION  = 0700;
$PUBLIC_FILE_PERMISSION = 0644;
$SECRET_FILE_PERMISSION = 0600;


use vars qw($EXT_LOG $EXT_PUBLIC $EXT_SECRET $EXT_GZIP $EXT_TEMP $EXT_LOCK);

$EXT_LOG      = 'log';     # ȯ�����Ǥ��뤳�Ȥ򤢤�魯��ĥ��
$EXT_PUBLIC   = 'pub';     # ��������Ƥ��뤳�Ȥ򤢤�魯��ĥ��
$EXT_SECRET   = 'sec';     # ������Ǥ��뤳�Ȥ򤢤�魯��ĥ��
$EXT_GZIP     = 'gz';      # gzip���̤γ�ĥ��
$EXT_TEMP     = $$;        # ����ե������ĥ��
$EXT_LOCK     = 'lock';    # ��å��ե������ĥ��


#
# ���ץ�����߷׾�ν������
#
#  �ե�������å��������å�����Ȥ����ʲ��Τ褦�˽��֤��뤳��
#
#  1. �ݥ��󥿥ե�����
#  2. ���ե����������
#  3. ���ե������������
#
#  ���ν��֤���ʤ���硢�������֤�Ĺ���ʤä���
#  �ǥåɥ�å��򵯤�����ǽ��������ޤ�.
#



##########################################################################
#                       �Ķ�����ե�������ɤ߹���                       #
##########################################################################
sub config_read{
	my $conf = shift;   # �ʻ��ȡ˴Ķ�������¸�ѥϥå���

	# �ǥե�����ͤ򥻥åȤ���
	%$conf = config_default();

	# �Ķ�����ե�����򥪡��ץ󤹤�
	my $config_file = config_name();
	open(FIN, $config_file) || return 0;

	# ���Ԥ��ĴĶ�����ե�������ɤ߼�ꡢ���Ϥ��Ƥ���
	until(eof(FIN)){
		my $read = <FIN>;
		chomp($read);

		$read=~s/\s+\#.*$//;     # ��Զ����'#'��������ʸ����
		$read=~s/\s*$//;         # ��������ʸ�����
		next if ($read eq '');   # ����Ԥ����ξ��Ͻ������ʤ�
		next if ($read=~m/^\#/); # �����ȹԤϽ������ʤ�

		my ($elements, $contents) = split(/\s*=\s*/, $read ,2);  # ʬΥ
		$elements =~tr/a-z/A-Z/;                                 # �Ķ�����̾����ʸ���Ѵ�
		$$conf{$elements} = $contents;                           # ��Ǽ

	}
	close(FIN);

	return 0 unless(config_check($conf));  # �Ķ����꤬�����ʤ饨�顼���֤�
	return 1;
}


##########################################################################
#                      �Ķ��Υǥե�����ͤ����ꤹ��                      #
##########################################################################
sub config_default{

	# �ǥե�����ͤ����ꡧ����Ū������
	my %conf;
	#$conf{'BASE_HTTP'}         = (�ʤ�)                   # �Ǽ��ĵ����Ȥʤ�URI
	#$conf{'ADMIN_MAIL'}        = (�ʤ�)                   # �����ԥ᡼�륢�ɥ쥹
	$conf{'BBS_NAME'}           = '���֥륹��åɷǼ���';  # �Ǽ��Ĥ�̾��
	$conf{'NO_NAME'}            = '̵̾';                  # ��ƻ���̾�������Ϥ���ʤ��ä��Ȥ����������̾��
	$conf{'NO_TITLE'}           = '̵��';                  # ��ƻ�����̾�����Ϥ���ʤ��ä��Ȥ������������̾
	$conf{"THREAD_LENGTH_MAX"}  = 30;                      # ����å�̾��Ĺ������Ȥ��ˤɤ��Ǥ�����ڤ뤫��
	$conf{'TITLE_LENGTH_MAX'}   = 20;                      # �����ȥ뤬Ĺ������Ȥ��ˤɤ��Ǥ�����ڤ뤫��
	$conf{'NAME_LENGTH_MAX'}    = 10;                      # ̾����Ĺ������Ȥ��ˤɤ��Ǥ�����ڤ뤫��
	$conf{'KILL_TITLE'}         = '�������ޤ���';        # ������줿ȯ����ɽ�魯ɽ���ʥ����ȥ��
	$conf{'KILL_NAME'}          = '�������ޤ���';        # ������줿ȯ����ɽ�魯ɽ����̾����
	$conf{'EXIT_TO'}            = '/';                     # �Ǽ��Ĥ���ȴ����Ȥ���������Υ��
	$conf{'FORCE_TOMATO'}       = 0;                       # ��ƼԤ�IP���ɥ쥹����ɽ��
	$conf{'CREATE_ID'}          = 1;                       # ��ƼԸ�ͭID����������

	$conf{'ACCEPT_CHANGE'}      = 1;                       # ȯ�����ѹ�������������ǧ��뤫
	$conf{'COOKIE_EXPIRES'}     = 7;                       # cookieͭ������
	$conf{'ID_LENGTH'}          = 5;                       # ID��Ĺ��
	$conf{'DISPLAY_LAST'}       = 100;                     # �ǿ��쥹ɽ���򤤤��Ĥޤ�ɽ�����뤫
	$conf{'TRIP_INPUT_LENGTH'}  = 10;                      # �ȥ�åפ�Ĺ�������ϡ�
	$conf{'TRIP_OUTPUT_LENGTH'} = 10;                      # �ȥ�åפ�Ĺ���ʽ��ϡ�
	$conf{'TRIP_KEY'}           = 'aa';                    # �ȥ�å׸�
	$conf{'PASSWORD_LENGTH'}    = 20;                      # ���ϥѥ���ɤκ���Ĺ���ʺǾ���8��

	# �ǥե�����ͤ����ꡧ�꥽��������
	$conf{'THREAD_SAVE'}    = 20;      # ����åɤ򤤤��Ĥޤ���¸���뤫
	$conf{'THREAD_MAX'}     = 5;       # ���ͤ����ꥹ��åɤ򤤤��ĺ����Ǥ��뤫 
	$conf{'BUFFER_LIMIT'}   = 5000;    # ��ȯ�����礭�����¡ʥХ��ȿ���

	                                    # ����åɤؤν񤭹������¡ʥХ��ȿ���
	$conf{'FILE_LIMIT'}     = 1000000;  # ����߶ػ�
	$conf{'FILE_WARNING'}   = 900000;   # �ٹ�ɽ��
	$conf{'FILE_CAUTION'}   = 800000;   # ��մ���

	                                    # ����åɤؤν񤭹������¡�ȯ������
	$conf{'THREAD_LIMIT'}   = 1000;     # ����߶ػ�
	$conf{'THREAD_WARNING'} = 950;      # �ٹ�ɽ��
	$conf{'THREAD_CAUTION'} = 900;      # ��մ���

	$conf{'CHANGE_LIMIT'}   = 5;        # ȯ���������Ǥ�����
	$conf{'DUPE_BACK'}      = 5;        # �����Ƥ�Ƚ�Ǥ�ȯ���ޤ��̤äƸ��뤫
	$conf{'CHAIN_POST'}     = 1;        # Ϣ³��ƹӤ餷�ɻߵ�����������
	$conf{'CHAIN_TIME'}     = 30;       # Ϣ³��ƹӤ餷�ɻߵ������ƻ����

	# �ǥե�����ͤ����ꡧ�����ƥ�����
	$conf{'LOG_DIR_PUBLIC'} = './public_log/';       # �Ǽ��ĤΥ��Τ���������������Τ���¸����ǥ��쥯�ȥ�
	$conf{'LOG_DIR_SECRET'} = './secret_log/';       # �Ǽ��ĤΥ��Τ�������������ʤ���Τ���¸����ǥ��쥯�ȥ�
	$conf{'LOG_DIR_HTML'}   = './';                  # �Ǽ��ĤΥ��Τ�����HTML��������Τ���¸����ǥ��쥯�ȥ�
	$conf{'TEMP_DIR'}       = '/tmp/';               # �ƥ�ݥ��(����˥ե��������ǥ��쥯�ȥ�
	$conf{'FILE_LOCK'}      = 0;                     # �ե������å�����ˡ(0:�ʤ���1:symlink��2:mkdir)

	# ����¾�δĶ���
	$conf{'VERSION'} = 70;      # �С�������ֹ� x 100

	return %conf;
}


##########################################################################
#                �Ķ������������ꤵ��Ƥ��뤫�����å�����                #
##########################################################################
sub config_check{
	my $conf = shift;   # �ʻ��ȡ˴Ķ�������¸�ѥϥå���

	# ɬ�����ϳ�ǧ
	return 0 unless(defined($$conf{'BASE_HTTP'}));
	return 0 unless(defined($$conf{'ADMIN_MAIL'}));

	# ɬ��������������ǧ
	return 0 unless (std::uri_valid($$conf{'BASE_HTTP'}));
	return 0 unless (std::email_valid($$conf{'ADMIN_MAIL'}));

	# ���ͤ�������Τ�ʸ��������줿��������
	my @number_only = (
	                    'THREAD_LENGTH_MAX',
	                    'TITLE_LENGTH_MAX',
	                    'NAME_LENGTH_MAX',
	                    'FORCE_TOMATO',
	                    'CREATE_ID',
	                    'ACCEPT_CHANGE',
	                    'COOKIE_EXPIRES',
	                    'ID_LENGTH',
	                    'DISPLAY_LAST',
	                    'TRIP_INPUT_LENGTH',
	                    'TRIP_OUTPUT_LENGTH',
	                    'PASSWORD_LENGTH',
	                    'THREAD_SAVE',
	                    'THREAD_MAX',
	                    'BUFFER_LIMIT',
	                    'FILE_LIMIT',
	                    'FILE_WARNING',
	                    'FILE_CAUTION',
	                    'THREAD_LIMIT',
	                    'THREAD_WARNING',
	                    'THREAD_CAUTION',
	                    'CHANGE_LIMIT',
	                    'DUPE_BACK',
	                    'CHAIN_POST',
	                    'CHAIN_TIME',
	                    'FILE_LOCK',
	                   );

	foreach my $item(@number_only){
		return 0 unless($$conf{$item}=~m/^\d+$/);
	}

	# �����ϥ����å�
	return 0 if ($$conf{'BBS_NAME'}   eq '');
	return 0 if ($$conf{'NO_NAME'}    eq '');
	return 0 if ($$conf{'NO_TITLE'}   eq '');
	return 0 if ($$conf{'KILL_NAME'}  eq '');
	return 0 if ($$conf{'KILL_TITLE'} eq '');
	return 0 if ($$conf{'TRIP_KEY'}   eq '');

	# ˰�·ϥ����å�
	$$conf{'THREAD_LENGTH_MAX'}  = 5   if ($$conf{'THREAD_LENGTH_MAX'}  <   5);
	$$conf{'TITLE_LENGTH_MAX'}   = 5   if ($$conf{'TITLE_LENGTH_MAX'}   <   5);
	$$conf{'NAME_LENGTH_MAX'}    = 5   if ($$conf{'NAME_LENGTH_MAX'}    <   5);
	$$conf{'DISPLAY_LAST'}       = 10  if ($$conf{'DISPLAY_LAST'}       <  10);
	$$conf{'TRIP_INPUT_LENGTH'}  = 5   if ($$conf{'TRIP_INPUT_LENGTH'}  <   5);
	$$conf{'TRIP_OUTPUT_LENGTH'} = 5   if ($$conf{'TRIP_OUTPUT_LENGTH'} <   5);
	$$conf{'THREAD_SAVE'}        = 5   if ($$conf{'THREAD_SAVE'}        <   5);
	$$conf{'BUFFER_LIMIT'}       = 500 if ($$conf{'BUFFER_LIMIT'}       < 500);

	# �����������å�
	return 0 if ($$conf{'FILE_LIMIT'}   <= $$conf{'FILE_WARNING'} or
	             $$conf{'FILE_WARNING'} <= $$conf{'FILE_CAUTION'}  );

	return 0 if ($$conf{'THREAD_LIMIT'}   <= $$conf{'THREAD_WARNING'} or
	             $$conf{'THREAD_WARNING'} <= $$conf{'THREAD_CAUTION'}  );


	# symlink�ե������å������ѤǤ��ʤ��Ȥ��ϥ�å����ʤ�
	if ($$conf{'FILE_LOCK'} == 1){
		eval {   symlink("","");   };
		$$conf{'FILE_LOCK'} = 0 if ($@);
	}

	return 1;
}



##########################################################################
#                   �ե����롢�ǥ��쥯�ȥ�ν����                       #
##########################################################################
sub init{

	# �ǥ��쥯�ȥ����
	my @directorys = ($main::CONF{'LOG_DIR_PUBLIC'},
	                  $main::CONF{'LOG_DIR_SECRET'},
	                  $main::CONF{'LOG_DIR_HTML'}  ,
	                  $main::CONF{'TEMP_DIR'}      , 
	                 );

	# �����ѥ������������Ʊ���ǥ��쥯�ȥ����¸�������
	# �����ѥ��ǥ��쥯�ȥ����ʤ�
	shift(@directorys) if($main::CONF{'LOG_DIR_PUBLIC'} eq $main::CONF{'LOG_DIR_SECRET'});

	# �ǥ��쥯�ȥ����������
	foreach my $directory(@directorys){
		my $permission;
		if ($directory eq $main::CONF{'LOG_DIR_SECRET'}){  $permission = $SECRET_DIR_PERMISSION;  }
		else {  $permission = $PUBLIC_DIR_PERMISSION;  }
		chop($directory);
		unless(mkdir($directory, $permission)){
			return 0 unless (-d $directory);
		}
	}


	# �ݥ��󥿥ե��������
	my $pointer_file = pointer_name();
	unless(-e $pointer_file){
		return 0 unless(open(FOUT, ">$pointer_file"));
		print FOUT "0\n";
		close(FIN);
	}
	return 0 unless(chmod($SECRET_FILE_PERMISSION, $pointer_file));

	# ����åɷ��Ƥ����֥�å��ꥹ�ȥե��������
	my $blacklist_file = blacklist_name();
	#system("touch $blacklist_file");
	unless(-e $blacklist_file){
		return 0 unless(open(FOUT, ">$blacklist_file"));
		close(FOUT);
	}
	return 0 unless(chmod($SECRET_FILE_PERMISSION, $blacklist_file));

	# �������ѥѥ���ɥե��������
	my $password_file = adminpass_name();
	unless(-e $password_file){
		return 0 unless(open(FOUT, ">$password_file"));
		print FOUT "admin:\$1\$fdah\$eEx833FHr9nM6dMvboVou1\n";  # admin/admin
		close(FOUT);
	}
	return 0 unless(chmod($SECRET_FILE_PERMISSION, $password_file));

	# ���٤����ｪλ
	return 1;

}




##########################################################################
#                        ���ե�������ɤ߼��                          #
##########################################################################
sub read_log{
	my $no     = shift(@_); # ����å��ֹ�ʽ����ֹ�Τߡ�
	my $log    = shift(@_); # [����]�����Ƥ��֤�
	my $all    = shift(@_); # �����ͤ����λ�������åɾ���������ɤ߼��[$lock���ͤϾ�˵��Ȥ���]
	my $lock   = shift(@_); # �����ͤ����λ����ɤ߹�������ȥե������å��򤫤��äѤʤ��ˤ��롣
	my $gzip   = shift(@_); # �����ͤ����λ���gzip���̤������äƤ�����ե�������ɤࡣ

	# ���ե����뤬��¸����Ƥ���ǥ��쥯�ȥ�����
	my ($log_public, $log_secret, $lock_public, $lock_secret);
	$log_public = $lock_public = public_name($no);    # ��[������]
	$log_secret = $lock_secret = secret_name($no);    # ��[�������]


	# ���ե������õ������
	# ���ե����뤬�ʤ��Ȥ���gzip���̤��줿���ե�����̾�����
	unless(-f $log_public and -f $log_secret){
		return 0 unless($gzip);                # gzip�����򤷤ʤ����Ͻ�λ
		$lock_public .= ".$EXT_GZIP";
		$lock_secret .= ".$EXT_GZIP";
		return 0 unless(-f $lock_public and -f $lock_secret);
	}else{
		$gzip = 0;	# �̾�Υե����뤬���Ĥ��ä�����gzip�����Ϥ��ʤ��Ƥ���
	}

	# ��[���������������]���å�����
	return 0 unless(filelock($lock_public));
	unless(filelock($lock_secret)){
		clear($no);   return 0;
	}


	# gzipŸ����Ÿ�����줿���ե�����̾�����
	if ($gzip){
		gunzip($no);                                # gzipŸ��
		$log_public = gz_public_name($no);          # gzipŸ���������Υ�[������]
		$log_secret = gz_secret_name($no);          # gzipŸ���������Υ�[�������]
		unless(-f $log_public and -f $log_secret){  # gzipŸ������Ƥ��ʤ����Ͻ�λ
			return 0;
			clear($no);  return 0;
		}
	}


	# �ե�������������
	my @stat_public = stat($log_public);
	my @stat_secret = stat($log_secret);
	$$log[0]{'THREAD_NO'}     = $no;                                    # ����å��ֹ�
	$$log[0]{'SIZE'}          = $stat_public[7] + $stat_secret[7];      # �ե����륵����
	$$log[0]{'LAST_MODIFIED'} = $stat_public[9];                        # �ǽ���������
	$$log[0]{'DAT'}           = ($log_public eq $lock_public) ? 0 : 1;  # gzip�Υ����ɤ���


	# ��[���������������]�򳫤�
	unless(open(FIN_P, $log_public)){
		clear($no);  return 0;
	}
	unless(open(FIN_S, $log_secret)){
		close(FIN_P); clear($no);  return 0;
	}


	# ��[���������������]���饹��åɾ�����ɤ߽Ф�
	my $result = read_header(*FIN_P, $log);      # [������]
	if(!defined($result) or $result ne '&&'){    # ������»���Ƥ�����Ͻ�λ
		close(FIN_S);  close(FIN_P);  clear($no);  return 0;
	}
	$result = read_header(*FIN_S, $log);         # [�������]
	if(!defined($result) or $result ne '&&'){    # ������»���Ƥ�����Ͻ�λ
		close(FIN_S);  close(FIN_P);  clear($no);  return 0;
	}


	# ����åɾ���������ɤ���Ͻ�λ
	unless($all){
		close(FIN_S);
		close(FIN_P);
		clear($no, 0);  # ����åɾ���������ɤ����ɬ����å���
		return 1;       # ������뤳�Ȥ����[��񤭤򤷤ʤ�����]
	}


	# ��[������]��ȯ���ǡ������ɤ߹���
	my $error_flag = 0;
	my $count_public = 0;
	until(eof(FIN_P)){

		# ��[������]�ν������إå�
		my $read = read_header(*FIN_P, $log, $count_public);
		unless(defined($read)){ $error_flag = 1; last; }
		if ($read eq '&&'){ ++$count_public; next; }

		# ��[������]�ν�������ʸ
		$read = read_body(*FIN_P, $log, $count_public);
		unless(defined($read)){ $error_flag = 1; last; }
		$$log[$count_public]{'BODY'} = $read;
		++$count_public;
	}
	close(FIN_P);


	# ���������ξ��Ͻ�λ
	if ($error_flag){
		clear($no);  return 0;
	}

	my $count_secret = 0;
	until(eof(FIN_S)){

		# ����������ν������إå�
		my $read = read_header(*FIN_S, $log, $count_secret);
		unless(defined($read)){ $error_flag = 1; last; }
		if ($read eq '&&'){ ++$count_secret; next; }

		# ����������ν�������ʸ
		$read = read_body(*FIN_S, $log, $count_secret);
		unless(defined($read)){ $error_flag = 1; last; }
		$$log[$count_secret]{'BODY'} = $read;
		++$count_secret;
	}
	close(FIN_S);

	# ���ե����������������å�
	$error_flag = 1 unless($count_public == $count_secret and $count_secret == $$log[0]{'POST'});
	if($error_flag){
		clear($no); return 0;
	}

	# ����������ɤ߼�줿���ν���
	clear($no, $lock);
	return 1;


	#
	#   ���ȥåѡ�'&','&&'���Ф�ޤǥ��إå���ʬ����ɤ���
	#
	sub read_header{
		local(*FIN) = shift;  # �ե�����ϥ�ɥ�
		my $log     = shift;  # [����]�ǡ�����Ǽ��
		my $count   = shift;  # ���ߺ�Ȥ��Ƥ���ȯ���ֹ�

		loop: for(;;){

			# ����ʸ��������EOF���褿�Ȥ���̤����ͤ��֤�
			return undef if (eof(FIN));

			# �����ɤࡿ���ڤ�ʸ���򸫤Ĥ����餽����֤�
			my $read = <FIN>;
			chomp($read);
			return $read if ($read eq '&' or $read eq '&&');

			# ���������Ƥ�ʬΥ
			my ($key, $value) = split(/<>/, $read, 2);

			# ��������ʸ����
			$key=~tr/a-z/A-Z/;

			# ����åɾ��� [��������Ƭ��ʬ] ����
			my @thread_data = ('THREAD_TITLE', 'POST', 'AGE_TIME',
						'BUILDER_IP_ADDR', 'BUILDER_IP_HOST');  # �ü����5�ѥ�᡼��
			foreach my $element(@thread_data){
				if ($key eq $element){
					$$log[0]{$key} = $value;
					next loop;
				}
			}

			# ������ [������] ���ѹ����� �ü����
			if ($key eq 'CORRECT_TIME'){
				push(@{$$log[$count]{'CORRECT_TIME'}}, $value);
				next loop;
			}

			# ������ [���������������] ȯ���ֹ� �ü����
			if ($key eq 'NO'){

				# ��Ͽ����Ƥ���ȯ���ֹ���ɤ߽Ф��Ƥ���ȯ���ο���
				# ���äƤ��뤫�����å�����
				return undef unless ($count == $value);                    # ����
				if (defined($$log[$count]{'NO'})){
					return undef unless ($$log[$count]{'NO'} == $value);   # ����
					$$log[$count]{'NO'} = $value;                          # or $count ; ���ޤ��̣���ʤ�
				}
				next loop;
			}

			# ������ [�������] IP���ɥ쥹 IP�ۥ��� �桼������������� �ü����
			if ($key eq 'IP_HOST' or $key eq 'IP_ADDR' or $key eq 'USER_AGENT'){
				push(@{$$log[$count]{$key}}, $value);
				next loop;
			}

			# ������[���������������] ���̽���
			$$log[$count]{$key} = $value;
			next loop;
		}
	}

	#
	#   ���ȥåѡ�'&&'���Ф�ޤǥ���ʸ��ʬ���ɤ߼��
	#
	sub read_body{
		local(*FIN) = shift;  # �ե�����ϥ�ɥ�

		my $body = '';
		for(;;){
			return undef if(eof(FIN));        # ���륢��
			my $read = <FIN>;
			chomp($read);
			if ($read eq '&&'){               # ���ڤ국��ޤ��ɤ��
				chomp($body);
				return $body;
			}
			return undef if ($read eq '&');   # ���륢��
			$body .= "$read\n";
		}
	}



}


#
#   gzip���̤���Ƥ�����ե������ƥ�ݥ����
#   �ǥ��쥯�ȥ��Ÿ������
#
sub gunzip{
	my $no   = shift;
	my $lock = shift;  # ���λ�����å��򤫤���

	# ���ԡ����ե�ѥ�
	my $gzip_log_public_from = public_name($no) . ".$EXT_GZIP";
	my $gzip_log_secret_from = secret_name($no) . ".$EXT_GZIP";

	# �ե������å�
	if ($lock){
		return 0 unless(filelock($gzip_log_public_from) and
		                filelock($gzip_log_secret_from)      );
	}

	# ���ԡ���ǥ��쥯�ȥ�
	my $gzip_log_public_to = gz_public_name($no) . ".$EXT_GZIP";
	my $gzip_log_secret_to = gz_secret_name($no) . ".$EXT_GZIP";

	# �ƥ�ݥ���ѥǥ��쥯�ȥ�˥��ԡ�
	copy($gzip_log_public_from, $gzip_log_public_to);
	copy($gzip_log_secret_from, $gzip_log_secret_to);
####	system("cp $gzip_log_public_from $gzip_log_public_to");
####	system("cp $gzip_log_secret_from $gzip_log_secret_to");

	# �ե������å����
	unlock($gzip_log_public_from);
	unlock($gzip_log_secret_from);

	# gzipŸ��
####	system("gunzip $gzip_log_public_to");
####	system("gunzip $gzip_log_secret_to");
	rename($gzip_log_public_to, gz_public_name($no));
	rename($gzip_log_secret_to, gz_secret_name($no));

}


#
#   gzip���̤���Ƥ�����ե������Ÿ������
#
sub gunzip_only{
	my $no = shift;

	# Ÿ��������ե�����
	my $gzip_log_public = public_name($no) . ".$EXT_GZIP";
	my $gzip_log_secret = secret_name($no) . ".$EXT_GZIP";

	# �ե������å�
	return 0 unless(filelock($gzip_log_public) and filelock($gzip_log_secret));

	# gzipŸ��
####	system("gunzip $gzip_log_public");
####	system("gunzip $gzip_log_secret");
	rename($gzip_log_public, public_name($no));
	rename($gzip_log_secret, secret_name($no));

	# �ե������å����
	unlock($gzip_log_public);
	unlock($gzip_log_secret);

	return 1;
}


#
# ���ե������gzip���̤���
#
sub gzip{
	my $no = shift;
	my $log_public = public_name($no);
	my $log_secret = secret_name($no);

	return 0 unless(filelock($log_public) and filelock($log_secret));

####	system('gzip $log_public');
####	system('gzip $log_secret');
	rename($log_public, "$log_public.$EXT_GZIP") or return 0;
	rename($log_secret, "$log_secret.$EXT_GZIP") or return 0;
	unlock($log_public) or return 0;
	unlock($log_secret) or return 0;
	return 1;
}




#
#   �����ɤ߼��������äƺ�����������ե������
#   ��å��ե������������
#
sub clear{
	my $no   = shift;  # ȯ���ֹ�
	my $lock = shift;  # ��å��������뤫�ɤ�����
	                   #�ʵ��ʤ������ǥե����ư����å�����Ȥ��뤿���

	# ��å���������
	unless($lock){
		unlock(public_name($no));
		unlock(secret_name($no));
		unlock(public_name($no) . ".$EXT_GZIP");
		unlock(secret_name($no) . ".$EXT_GZIP");
	}

	# gzipŸ���������ե������������
	unlink(gz_public_name($no));
	unlink(gz_secret_name($no));

}



###########################################################################
#                    ����åɾ���������ɤ߹���                           #
###########################################################################
sub thread_read{
	my $thread = shift;   # ����åɾ���(����)
	my $gzip   = shift;   # �����ͤ����ΤȤ���dat�����줿����åɤξ�����ɤ߼��
	my $lock   = shift;   # ̤����

	# �ʸ����˥��ǥ��쥯�ȥ꤫����ե�����̾�������ɤ߹���
	return undef unless(opendir (DIR, $main::CONF{'LOG_DIR_PUBLIC'}));
	my @filenames = readdir(DIR);
	closedir(DIR);
	my @logfiles = grep(/^\d+\.$EXT_PUBLIC\.$EXT_LOG$/, @filenames);
	if ($gzip){
		push(@logfiles, grep(/^\d+\.$EXT_PUBLIC\.$EXT_LOG\.$EXT_GZIP$/, @filenames));
	}

	# ����򥹥�å��ֹ���Ѵ�����
	my @thread_no = map { $_=~s/^(\d+).*/$1/; $_=$1; } @logfiles;


	# �ǡ����������ɤ߹���
	my $c = 0;    # $c is counter.
	foreach my $no(@thread_no){
		my @log;
		next unless(file::read_log($no, \@log, 0, 0, 1));
		        # ��å��򤫤��ʤ����إå���ʬ�������ɤࡢgz�����б��򤹤�
		push(@$thread, $log[0]);
		$c++;
	}
	return $c;
}



##########################################################################
#                        ���ե�����򹹿�����                          #
##########################################################################
sub write_log{
	my $log = shift(@_);  # ��¸���������ǡ���

	# �Ƽ�ե�����̾�ǡ�������
	my $no          = $$log[0]{'THREAD_NO'};

	my $log_public  = public_name($no);
	my $log_secret  = secret_name($no);
	my $temp_public = temp_name($log_public);
	my $temp_secret = temp_name($log_secret);

	# ���ƥ�ݥ��ե�����[������]�򳫤�
	unless(open(TEMP, ">$temp_public")){
		unlock($log_public);
		unlock($log_secret);
		return 0;
	}

	# ����������åɾ����񤭹���
	print TEMP "THREAD_TITLE<>$$log[0]{'THREAD_TITLE'}\n";       # ����å�̾
	print TEMP "POST<>$$log[0]{'POST'}\n";                       # ��Ƥ���Ƥ����
	print TEMP "AGE_TIME<>$$log[0]{'AGE_TIME'}\n";               # ����åɤ��夬�ä�����
	print TEMP "&&\n";

	# ������ȯ�������񤭹���
	for(my $i=0;$i<$$log[0]{'POST'};++$i){

		print TEMP "NO<>$i\n";                                               # ȯ���ֹ�
		print TEMP "RES<>$$log[$i]{'RES'}\n" if (defined($$log[$i]{'RES'})); # �쥹���ֹ�

		# ȯ�����������Ƥ��ʤ����
		common_write(*TEMP, $$log[$i]) unless(defined($$log[$i]{'DELETE_TIME'}));
		sub common_write{
			local(*FOUT) = shift; # ������ե�����ϥ�ɥ�
			my $log = shift;
			print FOUT "TITLE<>$$log{'TITLE'}\n";                                     # ȯ�������ȥ�
			print FOUT "USER_NAME<>$$log{'USER_NAME'}\n";                             # ��ƼԻ�̾
			print FOUT "USER_EMAIL<>$$log{'USER_EMAIL'}\n";                           # ��Ƽ�e-mail
			print FOUT "USER_WEBPAGE<>$$log{'USER_WEBPAGE'}\n";                       # ��Ƽ�webpage
			print FOUT "USER_ID<>$$log{'USER_ID'}\n" if (defined($$log{'USER_ID'})); # ��ƼԸ�ͭID
			print FOUT "TRIP<>$$log{'TRIP'}\n" if (defined($$log{'TRIP'}));           # �ȥ�å�
		}

		# ����������ˡ
		print TEMP "TOMATO<>$$log[$i]{'TOMATO'}\n";                                 # IP���ɥ쥹ɽ��
		tomato_write(*TEMP, $$log[$i]) if ($$log[$i]{'TOMATO'});
		sub tomato_write{
			local(*FOUT) = shift; # ������ե�����ϥ�ɥ�
			my $log = shift;
			foreach my $ip_host(@{$$log{'IP_HOST'}}){                           # IP���ɥ쥹�ʥɥᥤ���
				print TEMP "IP_HOST<>$ip_host\n";
			}
			foreach my $ip_addr(@{$$log{'IP_ADDR'}}){                           # IP���ɥ쥹
				print TEMP "IP_ADDR<>$ip_addr\n";
			}
			foreach my $user_agent(@{$$log{'USER_AGENT'}}){                     # ���ѥ桼�������������
				print TEMP "USER_AGENT<>$user_agent\n";
			}
		}

		# ��ƽ�������
		print TEMP "POST_TIME<>$$log[$i]{'POST_TIME'}\n";                           # ��ƻ���
		foreach my $correct_time(@{$$log[$i]{'CORRECT_TIME'}}){
			print TEMP "CORRECT_TIME<>$correct_time\n";                         # ��������
		}

		# ȯ�����������Ƥ�����
		if (defined($$log[$i]{'DELETE_TIME'})){
			print TEMP "DELETE_TIME<>$$log[$i]{'DELETE_TIME'}\n";               # ȯ���������
			if (defined($$log[$i]{'DELETE_ADMIN'})){
				print TEMP "DELETE_ADMIN<>$$log[$i]{'DELETE_ADMIN'}\n";     # ȯ����ä���������
			}
		}else{
			print TEMP "&\n$$log[$i]{'BODY'}\n";                         # ȯ����ʸ
		}

		print TEMP "&&\n";                                               # ���ڵ���

	}
	close(TEMP);


	# ���ե�����[�������]�򳫤�
	unless(open(TEMP,">$temp_secret")){
		unlock($log_public);
		unlock($log_secret);
		return 0;
	}

	# �����������åɾ����񤭹���
	print TEMP "BUILDER_IP_ADDR<>$$log[0]{'BUILDER_IP_ADDR'}\n"; # ����åɺ����� IP���ɥ쥹
	print TEMP "BUILDER_IP_HOST<>$$log[0]{'BUILDER_IP_HOST'}\n"; # ����åɺ����� IP�ۥ���
	print TEMP "&&\n";

	# �������ȯ�������񤭹���
	for(my $i=0;$i<$$log[0]{'POST'};++$i){

		print TEMP "NO<>$i\n";                                           # ȯ���ֹ�

		# ȯ������ξ��
		common_write(*TEMP, $$log[$i]) if(defined($$log[$i]{'DELETE_TIME'}));
		tomato_write(*TEMP, $$log[$i]) unless($$log[$i]{'TOMATO'});

		print TEMP "PASSWORD<>$$log[$i]{'PASSWORD'}\n";                  # ȯ���ѹ��ѥѥ����

		if(defined($$log[$i]{'DELETE_TIME'})){
			print TEMP "&\n$$log[$i]{'BODY'}\n";                         # ȯ����ʸ
		}
		print TEMP "&&\n";                                               # ���ڵ���
	}
	close(TEMP);

	# ���ե����빹��
	chmod($PUBLIC_FILE_PERMISSION, $temp_public);
	chmod($SECRET_FILE_PERMISSION, $temp_secret);
	return 1 if (renew($log_public) and renew($log_secret));

	# ��������
	unlock($log_public);
	unlock($log_secret);
	return 0;

}



###########################################################################
#                    ����åɾ��󤫤�bbs.html���������                   #
###########################################################################
#
#  ���Υ��֥롼���������ʤ�write.cgi���֤����٤�ʪ�Ǥ�����
#  admin.cgi�Ȥζ������ѤȤʤ뤿�ᡢfile.pl���֤���뤳�Ȥˤʤ�ޤ���
#
sub create_bbshtml{
	my $thread      = shift;   # ����åɾ���[����]

	# bbs.html ���å�����
	my $bbs_html = "./$BBS_TOP_PAGE_FILE";
	return 0 unless (filelock($bbs_html));

	# bbs.html�إå�����
	my $tempfile = temp_name($bbs_html);
	return 0 unless(open(FOUT, ">$tempfile"));
	html::header(*FOUT, '����åɰ���ɽ��');

	# bbs.html��Ƭ����ʸ����
	my $info = '';
	open(FIN, $writecgi::THREADLIST_INFO);
	until(eof(FIN)){
		$info .= <FIN>;
	}
	$info = std::encodeEUC($info);
	print FOUT "<div class='info'>\n\n";
	print FOUT "$info\n";
	print FOUT "</div>\n\n";
	html::hr(*FOUT);

	# ��󥯥С�����
	print FOUT "<div class='link'>";
	print FOUT '<a href="#create-thread">��������åɺ���</a>��';
	html::link_exit(*FOUT);
	html::link_adminmode(*FOUT);
	html::link_adminmail(*FOUT);
	print FOUT "</div>\n\n";
	html::hr(*FOUT);

	# ����åɰ�����ʬ����
	print FOUT "<div class='thread'>\n\n";
	print FOUT "<h3 id='thread'>����åɰ���</h3>\n\n";
	html::thread_list(*FOUT, $thread);
	print FOUT "</div>\n\n";
	html::hr(*FOUT);

	# ��󥯥С�
	print FOUT "<div class='link'>";
	html::link_exit(*FOUT);
	html::link_adminmode(*FOUT);
	html::link_adminmail(*FOUT);
	print FOUT "</div>\n\n";
	html::hr(*FOUT);

	# ��������åɺ����ե��������
	print FOUT "<div class='create-thread'>\n\n";
	print FOUT "<h3 id='create-thread'>��������åɺ���</h3>\n\n";
	html::formparts_head(*FOUT);
	html::formparts_createthread(*FOUT);
	html::formparts_name(*FOUT, undef, '', '', undef, undef);
	html::formparts_password(*FOUT, 1, html::pass_message() );
	html::formparts_age(*FOUT, 0, 1);
	html::formparts_foot(*FOUT, $html::CREATE, $writecgi::CREATE);
	print FOUT "</div>\n\n";

	# ��󥯥С�
	print FOUT "<div class='link'>";
	html::link_exit(*FOUT);
	html::link_adminmode(*FOUT);
	html::link_adminmail(*FOUT);
	print FOUT "</div>\n\n";
	html::hr(*FOUT);

	# ������ʬ
	html::footer(*FOUT);
	close(FOUT);

	# �ƥ�ݥ��ե����뤫�������ե�������Ѵ�
	return renew($bbs_html);
}




###########################################################################
#                     �Ť��ʤä�����åɤ򰵽̽�������                    #
###########################################################################
sub compress{
	my $thread = shift;    # ����åɾ���[����]
	my $force  = shift;    # ����Ū���̤򤹤���

	# DAT�Ǥʤ�����åɤο��������
	my $live = 0;
	for(my $i=0;$i<scalar @$thread;++$i){
		++$live unless($$thread[$i]{'DAT'});
	}

	# ����åɰ��̾���ܰ�
	my $limit = $main::CONF{'THREAD_SAVE'} + std::math_max(10, $main::CONF{'THREAD_SAVE'} / 2);
	unless($force){
		return 0 unless($live > $limit);    # �����̤�Ķ���Ƥ��ʤ����Ͻ�����Ԥ�ʤ�
	}else{
		return 0 unless($live > $main::CONF{'THREAD_SAVE'});  # 1�ĤǤ�Ķ�����鰵�̤������Ƚ��
	}

	# ����ͥ���̤ǥ�����
	@$thread = sort {  $$b{'LAST_MODIFIED'} + $$b{'AGE_TIME'} / 2 <=> $$a{'LAST_MODIFIED'} + $$a{'AGE_TIME'} / 2  } @$thread;

	# Ķ�ᤷ������åɤν�����Ԥ�
	my ($c, $j) = (0, 0);
	for(my $i=0;$i<scalar @$thread;++$i){
		next if ($$thread[$i]{'DAT'});
		next if ($j++ < $main::CONF{'THREAD_SAVE'});
		if (file::gzip($$thread[$i]{'THREAD_NO'})){
			$$thread[$i] = undef;
			++$c;
		}
	}

	# ������������åɤ���
	@$thread = grep{ defined($_); } @$thread;
	return $c;

}


###########################################################################
#                      admin.html �����ڡ����򹹿�����                    #
###########################################################################
#
#  ���Υ��֥롼���������ʤ�write.cgi���֤����٤�ʪ�Ǥ�����
#  admin.cgi�Ȥζ������ѤȤʤ뤿�ᡢfile.pl���֤���뤳�Ȥˤʤ�ޤ���
#
sub create_adminpage{

	# ��������
	my $version      = sprintf("%1.2f",$main::CONF{'VERSION'} / 100);
	my $bbs_top      = "./$file::BBS_TOP_PAGE_FILE";
	my $stylesheet   = "./$html::STYLESHEET";
	my $admin_mail   = $main::CONF{'ADMIN_MAIL'};
	my $admin_script = "./$file::ADMIN_SCRIPT";
	my $programmer   = $html::PROGRAMMER_WEBPAGE;

	# admin.info���ɤ߹���
	return 0 unless(open(FIN, $writecgi::ADMIN_INFO));
	my $info = '';
	until(eof(FIN)){
		$info .= <FIN>;
	}
	$info = std::encodeEUC($info);
	$info =~ s/(\$\w+)/$1/gee;

	# admin.html�ν񤭽Ф�
	my $admin_html = "./$html::ADMIN_PAGE";
	return 0 unless (filelock($admin_html));
	my $tempfile = temp_name($admin_html);
	return 0 unless(open(FOUT, ">$tempfile"));
	print FOUT $info;
	close(FOUT);

	# �ƥ�ݥ��ե����뤫�������ե�������Ѵ�
	return renew($admin_html);


}


##########################################################################
#                      �ݥ��󥿥ե�������ɤ߹���                        #
##########################################################################
sub read_pointer{
	my $lock = shift;    # �����ͤ����λ����ɤ߹�������ȥե������å��򤫤��äѤʤ��ˤ���

	# ��å����ե����뤫���ɤ߹���
	my $pointer_file = pointer_name();
	return undef unless (filelock($pointer_file) and open(FIN, $pointer_file));
	my $read=<FIN>;
	close(FIN);
	unlock($pointer_file) unless($lock);

	# ����
	chomp($read);
	return undef unless ($read=~m/^(\d+)$/);
	return $1;
}


##########################################################################
#                         �ݥ��󥿥ե�����򹹿�����                     #
##########################################################################
sub write_pointer{

	#
	# ���ν�����¹Ԥ������˥ݥ��󥿥ե������
	# ��å����Ƥ������Ȥ�ɬ��
	#
	my $pointer = shift;                  # �������ݥ�����

	my $pointer_file = pointer_name();
	my $pointer_temp = temp_name($pointer_file);
	unless(open(TEMP,">$pointer_temp")){
		unlock($pointer_file);
		return 0;
	}
	print TEMP "$pointer\n";
	close(TEMP);
	chmod($SECRET_FILE_PERMISSION, $pointer_temp);
	return renew($pointer_file);
}


##########################################################################
#               ����åɷ��Ƥ����֥�å��ꥹ�Ȥ��ɤ߹���                 #
##########################################################################
sub read_overbuilder{
	my $list = shift;

	open(FIN, blacklist_name()) || return 0;
	my @dat = <FIN>;
	close(FIN);

	foreach my $line(@dat){
		chomp($line);
		push(@$list, $line);
	}
	return 1;
}

##########################################################################
#               ����åɷ��Ƥ����֥�å��ꥹ�Ȥ򹹿�����                 #
##########################################################################
sub write_overbuilder{
	#
	# ����äƥե�������å����Ƥ�������
	#

	# �ե����륪���ץ�
	my $filename = blacklist_name();
	my $tempfile = temp_name($filename);
	unless(open(TEMP, ">$tempfile")){
		unlock($filename);
		return 0;
	}

	# �֥�å��ꥹ�Ƚ񤭹��ߡ�����
	foreach my $line(@_){
		print TEMP "$line\n";
	}
	close(TEMP);
	chmod($SECRET_FILE_PERMISSION, $tempfile);
	return renew($filename);
}


###########################################################################
#                         �����ԥѥ���ɤ��ɤ߹���                      #
###########################################################################
sub read_adminpass{
	my $passwords = shift;       # (����)�ѥ���ɥǡ���������
	my $lock      = shift;       # ̤����
	my $pass_file = adminpass_name();
	return 0 unless (open(FIN, $pass_file));
	foreach my $line(<FIN>){
		chomp($line);
		my ($user, $pass) = split(/:/, $line, 2);
		$$passwords{$user} = $pass;
	}
	close(FIN);
	return 1;
}


###########################################################################
#                         �����ԥѥ���ɤ�񤭹���                      #
###########################################################################
sub write_adminpass{
	#
	# ���ν�����¹Ԥ������˥ѥ���ɰ����ե������
	# ��å����Ƥ������Ȥ�ɬ��
	#
	my $passwords = shift;                  # (����)�ѥ���ɥǡ���������
	my $pass_file = adminpass_name();
	my $pass_temp = temp_name($pass_file);

	unless(open(TEMP,">$pass_temp")){
		unlock($pass_file);
		return 0;
	}
	my ($user, $pass);
	while ( ($user, $pass) = each(%$passwords) ){
		print TEMP "$user:$pass\n";
	}
	close(TEMP);
	chmod($file::SECRET_FILE_PERMISSION, $pass_temp);
	return renew($pass_file);

}


##########################################################################
#                 �ե�������å�����/��å������Ԥ�                    #
##########################################################################
sub filelock{
	my $filename = shift;                  # ��å�����ե�����̾

	return 0 unless(-f $filename);
	return 1 if ($main::CONF{'FILE_LOCK'} == 0);            # �ե������å��ʤ�

	my $lockfile = lock_name($filename);
	foreach (1..10){

		unless(lock_check($filename)){

			if ($main::CONF{'FILE_LOCK'} == 1){     # symlink��å�
				my $lock_ok;
				eval "$lock_ok = symlink($filename, $lockfile)";
				return 0 if ($@);
				return 1 if ($lock_ok);

			}else{                                  # mkdir��å�
				return 1 if (mkdir($lockfile, 0755));

			}
		}
		if ($TIME_HIRES_OK){
			sleep(0.1);	# 0.1���Ԥ�(Time::Hires����)
		}else{
			sleep(1);	# 1���Ԥ�(�̾�)
		}
	}
	return 0;
}


##########################################################################
#          �ե����뤬��å�����Ƥ��뤫�ɤ��������å�����                #
##########################################################################
sub lock_check{

	if ($main::CONF{'FILE_LOCK'} == 0){      # �ե������å��ʤ�
		return 1;

	}elsif ($main::CONF{'FILE_LOCK'} == 1){  # symlink��å�
		return (-l lock_name(shift));

	}else{                                   # mkdir��å�
		return (-d lock_name(shift));

	}
}


##########################################################################
#                       �ե�����Υ�å���������                       #
##########################################################################
sub unlock{
	if ($main::CONF{'FILE_LOCK'} == 0){      # �ե������å��ʤ�
		return 1;

	}elsif ($main::CONF{'FILE_LOCK'} == 1){  # symlink��å�
		return unlink(lock_name(shift));

	}else{                                   # rmdir��å�
		return rmdir(lock_name(shift));

	}
}


##########################################################################
#           �ƥ�ݥ��ե�������Ѵ����ƥե�����򹹿�����               #
##########################################################################
sub renew{
	my $filename = shift;                  # �����������ե�����

	my $lockfile = lock_name($filename);   # ��å��ե�����
	my $tempfile = temp_name($filename);   # �ƥ�ݥ��ե�����

	# ������ɬ�פʥե����뤬����äƤ��뤫�����å�����
	return 0 unless (-e $filename);
	return 0 unless (-e $tempfile);
#	return 0 unless (lock_check($filename));

	# �Ѵ�
	move($tempfile, $filename);    # ����
#	rename($tempfile, $filename);  

	if ($main::CONF{'FILE_LOCK'} == 2){   # ��å������rmdir���Ѥξ���
		rmdir($lockfile);
	}else{                                # ��å�����ʤ���¾��
		unlink($lockfile);
	}

	# �ƥ�ݥ��ե����뤬�ĤäƤ���Ȥ�������˽񤭴���äƤ��ʤ�
	# �����Ǥʤ��Ȥ�������
	return 0 if (unlink($tempfile) > 0);
	return 1;
}



##########################################################################
#                         �Ƽ�ե�����̾�����ͥ졼����                   #
##########################################################################

#
# �������ե�����̾����������
#
sub public_name{
	my $no = shift;
	return "$main::CONF{'LOG_DIR_PUBLIC'}$no.$EXT_PUBLIC.$EXT_LOG";
}


#
# ��������ե�����̾����������
#
sub secret_name{
	my $no = shift;
	return "$main::CONF{'LOG_DIR_SECRET'}$no.$EXT_SECRET.$EXT_LOG";
}


#
# gzip���̤��������������ե�����̾����������
#
sub gz_public_name{
	my $no = shift;
	return "$main::CONF{'TEMP_DIR'}$no.$EXT_PUBLIC.$EXT_LOG";
}


#
# gzip���̤���������������ե�����̾����������
#
sub gz_secret_name{
	my $no = shift;
	return "$main::CONF{'TEMP_DIR'}$no.$EXT_SECRET.$EXT_LOG";
}


#
# ��å��ե�����̾����������
#
sub lock_name{
	my $filename = shift;
	return $main::CONF{'TEMP_DIR'} . sha1_hex($filename) . ".$EXT_LOCK";
}


#
# �ƥ�ݥ��ե�����̾����������
#
sub temp_name{
	my $filename = shift;
	return $main::CONF{'TEMP_DIR'} . sha1_hex($filename) .  ".$EXT_TEMP";
}


#
# �ݥ��󥿥ե�����̾����������
#
sub pointer_name{
	return $main::CONF{'LOG_DIR_SECRET'} . $POINTER_FILE;
}


#
# ����åɷ��Ƥ����֥�å��ꥹ�ȥե�����̾����������
#
sub blacklist_name{
	return $main::CONF{'LOG_DIR_SECRET'} . $BLACKLIST_FILE;
}


#
# ����ե����ե�����̾����������
#
sub config_name{
	return $CONFIG_DIR . $CONFIG_FILE;
}


#
# HTML���ѤߤΥ��ե�����̾���������
#
sub html_name{
	return $main::CONF{'LOG_DIR_HTML'} . shift() . '.html';
}


#
# �����ԥѥ���ɥե�����̾����������
#
sub adminpass_name{
	return "$main::CONF{'LOG_DIR_SECRET'}$PASSWORD_FILE";
}

##########################################################################
#                               ����ΰ�                               #
##########################################################################



1;


