
# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Auth;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::Search::Cluster',
);

=head1 NAME

Kernel::System::Search::Auth - Base search engine auth related functions

=head1 DESCRIPTION

Functions to authenticate

=head1 PUBLIC INTERFACE

=head2 new()

my $SearchAuthObject = $Kernel::OM->Get('Kernel::System::Search::Auth');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=head2 ClusterCommunicationNodeAuthPwd()

get authentication password for engine communication node

    my $AuthData = $SearchAuthESObject->ClusterCommunicationNodeAuthPwd(
        Login => $Login,
        Pw    => $Password,
    )

=cut

sub ClusterCommunicationNodeAuthPwd {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    # check needed params
    for my $Name (qw(Login Pw)) {
        if ( !$Param{$Name} ) {
            if ( !$Param{Silent} ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "Need $Name!"
                );
            }
            return;
        }
    }

    # get params
    my $Login = $Param{Login} || '';
    my $Pw    = $Param{Pw}    || '';

    my $Method      = 'plain';
    my $DecryptedPw = '';

    if ( $Method eq 'plain' ) {
        $DecryptedPw = $Pw;
    }

    if ($DecryptedPw) {
        return {
            Login    => $Param{Login},
            Password => $DecryptedPw,
        };
    }

    # could not decrypt password
    return;
}

=head2 _ClusterCommunicationNodeSetPassword()

set password to communication node

    my $Result = $ClusterObject->_ClusterCommunicationNodeSetPassword(
        NodeID        => 1,
        Password      => 'admin',
        Login         => 'admin',
        PasswordClear => 1 # possible "1", "0"
    );

=cut

sub _ClusterCommunicationNodeSetPassword {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    for my $Name (qw(NodeID)) {
        if ( !$Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    if ( !$Param{PasswordClear} && ( !$Param{Password} && !$Param{Login} ) ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Either PasswordClear or Password and Login is required!"
        );
        return;
    }

    if ( $Param{PasswordClear} && $Param{Password} && $Param{Login} ) {
        $LogObject->Log(
            Priority => 'error',
            Message =>
                "Can't proceed with all parameters specified. Either PasswordClear or Password and Login is required!"
        );
        return;
    }

    my $SearchClusterObject = $Kernel::OM->Get('Kernel::System::Search::Cluster');
    my $DBObject            = $Kernel::OM->Get('Kernel::System::DB');

    # get node
    my $ClusterCommunicationNode = $SearchClusterObject->ClusterCommunicationNodeGet(
        NodeID => $Param{NodeID},
    );

    if ( !$ClusterCommunicationNode ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'No such Node!',
        );
        return;
    }

    my $Password  = $Param{Password} || '';
    my $CryptedPw = '';

    my $CryptType = 'plain';

    my $Login = $Param{Login};

    # TODO: Possible add another ways of storing passwords to be more protected
    # OTRS needs decrypted password when sending to engine,
    # so no hash alghoritms can be used here.
    # For now only plain storage.

    if ( !$Param{PasswordClear} ) {

        # crypt plain (no crypt at all)
        if ( $CryptType eq 'plain' ) {
            $CryptedPw = $Password;
        }
    }
    else {
        $CryptedPw = 'NULL';
    }

    # update db
    return if !$DBObject->Do(
        SQL => "UPDATE search_cluster_nodes SET node_password = ? "
            . " WHERE id = ?",
        Bind => [ \$CryptedPw, \$Param{NodeID} ],
    );

    if ( !$Param{PasswordClear} ) {

        # log notice
        $LogObject->Log(
            Priority => 'notice',
            Message =>
                "Cluster communication node name: $ClusterCommunicationNode->{Name}, login: '$Login' changed password successfully!",
        );
    }

    return 1;
}

1;
