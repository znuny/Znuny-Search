# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Engine;

use Search::Elasticsearch;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log'
);

=head1 NAME

Kernel::System::Search::Engine - TO-DO

=head1 DESCRIPTION

TO-DO

=head1 PUBLIC INTERFACE


=head2 new()

TO-DO

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=head2 Connect()

TO-DO

=cut

sub Connect {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    $LogObject->Log(
        Priority => 'error',
        Message  => "QueryExecute function was not properly overriden.",
    );

    return {
        ConnectionError => 1
    };
}

=head2 QueryExecute()

TO-DO

=cut

sub QueryExecute {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    $LogObject->Log(
        Priority => 'error',
        Message  => "QueryExecute function was not properly overriden.",
    );

    return {
        ConnectionError => 1
    };
}

1;
