# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::TicketHistory;

use strict;
use warnings;

use parent qw( Kernel::System::Search::Object::Base );

our @ObjectDependencies = (
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::Search::Object::TicketHistory - common base backend functions for "TicketHistory" index

=head1 DESCRIPTION

TO-DO

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchTicketHistoryObject = $Kernel::OM->Get('Kernel::System::Search::Object::TicketHistory ');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # Engine site "ticket_history" index unique key.
    $Self->{ResultFormat}->{Identifier}
        = 'TicketHistoryID';    # TODO Specify after implementation for TicketHistory ObjectIndexAdd

    return $Self;
}

1;
