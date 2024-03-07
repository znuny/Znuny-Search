# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Event::ObjectIndex::TicketHistory;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Search',
    'Kernel::System::Search::Object',
    'Kernel::System::Search::Object::Default::TicketHistory',
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

    my $LogObject         = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');
    return if $SearchObject->{Fallback};

    NEEDED:
    for my $Needed (qw(Data Event Config)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!"
        );
        return;
    }

    my $SearchTicketHistoryObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::TicketHistory');

    my $FunctionName = $Param{Config}->{FunctionName};
    my $TicketID     = $Param{Data}->{TicketID};

    my $Query;

    if ( $Param{Event} eq 'TicketMerge' ) {
        my $MergedIntoTicketID = $Param{Data}->{MainTicketID};

        $SearchChildObject->IndexObjectQueueEntry(
            Index => 'TicketHistory',
            Value => {
                Operation   => 'ObjectIndexSet',
                QueryParams => {
                    TicketID => $TicketID,
                },
                Context => "ObjectIndexSet_TicketMerge_$TicketID",
            },
        );

        $SearchChildObject->IndexObjectQueueEntry(
            Index => 'TicketHistory',
            Value => {
                Operation   => 'ObjectIndexSet',
                QueryParams => {
                    TicketID => $MergedIntoTicketID,
                },
                Context => "ObjectIndexSet_TicketMerge_$MergedIntoTicketID",
            },
        );
    }
    elsif ( $Param{Event} eq 'HistoryDelete' ) {
        $SearchChildObject->IndexObjectQueueEntry(
            Index => 'TicketHistory',
            Value => {
                Operation   => 'ObjectIndexRemove',
                QueryParams => {
                    TicketID => $TicketID,
                },
                Context => "ObjectIndexRemove_HistoryDelete_$TicketID",
            },
        );
    }
    elsif ( $Param{Event} eq 'HistoryAdd' ) {

        # at this moment last ticket history from the sql table
        # is the ticket history entry that caused the event
        # get it to save into indexing queue afterwards
        # as event does not return ticket history id entry
        my $TicketHistoryID = $SearchTicketHistoryObject->ObjectListIDs(
            QueryParams => {
                TicketID => $TicketID,
            },
            Limit   => 1,
            OrderBy => 'Down',
        );

        $SearchChildObject->IndexObjectQueueEntry(
            Index => 'TicketHistory',
            Value => {
                Operation => 'ObjectIndexAdd',
                ObjectID  => $TicketHistoryID->[0],
            },
        );
    }

    return 1;
}

1;
