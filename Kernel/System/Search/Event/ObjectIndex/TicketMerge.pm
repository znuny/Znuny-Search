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

use Kernel::System::VariableCheck qw(:all);

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

        # update articles of changed tickets
        $SearchChildObject->IndexObjectQueueAdd(
            Index => 'Article',
            Value => {
                FunctionName => 'ObjectIndexSet',
                QueryParams  => {
                    TicketID => $Param{Data}->{$Ticket},
                },
                Context => "ObjectIndexSet_TicketMerge_$Param{Data}->{$Ticket}",
            },
        );

        # update tickets that contains changed articles
        $SearchChildObject->IndexObjectQueueAdd(
            Index => 'Ticket',
            Value => {
                FunctionName => 'ObjectIndexSet',
                ObjectID     => $Param{Data}->{$Ticket},
            },
        );
    }

    return 1;
}

1;
