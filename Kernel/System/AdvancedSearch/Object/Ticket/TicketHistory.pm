# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::AdvancedSearch::Object::Ticket::TicketHistory;

use strict;
use warnings;

use parent qw( Kernel::System::AdvancedSearch::Object::Ticket );

our @ObjectDependencies = (

);

=head1 NAME

Kernel::System::AdvancedSearch::Object::Ticket::TicketHistory - TO-DO

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

=head2 Search()

TO-DO

=cut

sub Search {
    my ( $Self, %Param ) = @_;

    return ['Ticket/TicketType Query1 GET'];    # MOCK-UP
}

1;
