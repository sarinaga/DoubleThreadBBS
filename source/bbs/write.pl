# 
#
# ���Ǥ����狼��ʤ��ΤǤ��������������ɤμ��̤˼��Ԥ���Τ�
# Ŭ������Ƭ��ʬ����ʸ��񤫤��Ƥ��������ޤ�����λ����
#
# ��������ʸ��񤤤��餦�ޤ�Ƚ�̤Ǥ������褫�ä����褫�ä���
#
#
#
# �ޥ������åɷǼ��� - write.pl
#
#                                          2002.10.23 ����������
#
#
#
use strict;
package writecgi;

use vars qw($CREATE $REVISE $DELETE $POST);
$CREATE = 'create';  # ��������åɺ���
$REVISE = 'revise';  # ȯ������
$DELETE = 'delete';  # ȯ�����
$POST   = 'post';    # ȯ�����

use vars qw($EMAIL $WEB $PASS_LENGTH_MIN $PASS_LENGTH_MAX);
$EMAIL       = 'EMAIL';
$WEB         = 'WEB';
$PASS_LENGTH_MIN = 5;
$PASS_LENGTH_MAX = 20;  # ������ʬ�϶�ʸ�����Ƥ���

use vars qw($THREADLIST_INFO $ADMIN_INFO);
$THREADLIST_INFO = 'threadlist.info';
$ADMIN_INFO      = 'admin.info';


##########################################################################
#                              �ƥ������ΰ�                              #
##########################################################################


1;
