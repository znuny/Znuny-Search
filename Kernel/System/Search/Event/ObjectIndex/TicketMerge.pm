# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Event::ObjectIndex::TicketMerge;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Search',
    'Kernel::System::Search::Object',
);

sub new {
    my ( $Type, %Param ) = @_;

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

    for my $Ticket (qw(TicketID MainTicketID)) {

        my $TicketID = $Param{Data}->{$Ticket};

        # update articles of changed tickets
        $SearchChildObject->IndexObjectQueueEntry(
            Index => 'Article',
            Value => {
                Operation   => 'ObjectIndexSet',
                QueryParams => {
                    TicketID => $TicketID,
                },
                Context => "ObjectIndexSet_TicketMerge_$TicketID",
            },
        );

        # delete queued article permission change operation
        # as previous one will still update ticket articles
        $SearchChildObject->IndexObjectQueueDelete(
            Index     => 'Article',
            Operation => 'ObjectIndexSet',
            Context   => "ObjectIndexSet_ArticlesPermissionChange_$TicketID",
        );

        # update tickets that contains changed articles
        $SearchChildObject->IndexObjectQueueEntry(
            Index => 'Ticket',
            Value => {
                Operation => 'ObjectIndexSet',
                ObjectID  => $TicketID,
            },
        );
    }

    return 1;
}

1;
