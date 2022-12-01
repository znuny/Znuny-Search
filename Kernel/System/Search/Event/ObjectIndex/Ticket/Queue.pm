# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Event::ObjectIndex::Ticket::Queue;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Search',
    'Kernel::System::Search::Object::Default::Ticket',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');
    return if $SearchObject->{Fallback};
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    # check needed parameters
    for my $Needed (qw(Data Event Config)) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # execute only on group change
    if ( $Param{Data}{OldQueue}->{GroupID} != $Param{Data}{Queue}->{GroupID} ) {
        my $IndexSearchObject = $Kernel::OM->Get("Kernel::System::Search::Object::Default::Ticket");

        my $TicketWithGroupToChange = $IndexSearchObject->SQLObjectSearch(
            QueryParams => {
                QueueID => $Param{Data}{OldQueue}->{QueueID},
            },
            Fields => ['TicketID'],
        );

        my @TicketIDs;
        for my $Ticket ( @{$TicketWithGroupToChange} ) {
            push @TicketIDs, $Ticket->{id};
        }

        my %QueryParam = (
            Index    => 'Ticket',
            ObjectID => \@TicketIDs
        );

        $SearchObject->ObjectIndexUpdate(
            %QueryParam,
            Refresh => 1,    # live indexing should be refreshed every time
        );
    }

    return 1;
}

1;
